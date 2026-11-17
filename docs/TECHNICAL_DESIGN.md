# Socira：技術設計

> 2026-11-18 試驗分支：方塊垂直尺寸為 1 m，地形高度與海床深度同比加倍；跳躍理論高度由 1.6 m 試調為 1.2 m，手感尚待確認。以下舊數值保留作為比較基準。

更新日期：2026-11-17。依目前程式與 Git 分支核對；實際測試結果見 [進度](PROGRESS.md)，玩法依據見 [遊戲設計](GAME_DESIGN.md)。整理前的逐輪技術快照保留於 [歷史技術文件](TECHNICAL_DESIGN_HISTORY.md)，其中舊「未實作」不代表現況。

## 現行技術與分支

- 已確認 Godot 4、GDScript、3D；本機既往使用 Godot 4.6、D3D12 Forward+／Jolt 驗證。特定小版本、渲染與物理設定為現有配置，不因此變成永久設計限制。
- 目前 `feature/block-terrain-prototype`：半高方塊、斜坡及跳躍；比較分支 `feature/island-coast-prototype`：平滑低丘與海岸。本土平地均保留。
- 本機 main 已包含先前 UI 與自動存檔調整；地形分支未合併 main。origin 已設定為 [GitHub Socira](https://github.com/TWjustin/Socira)，本機 origin/main 記錄停在 7986e77；本次未連線查詢或同步遠端。
- Git 忽略 .godot 快取，追蹤腳本 .uid 與資源 .import 設定；使用者未追蹤圖片資料夾不自行納入提交。

## 程式與場景分工

| 路徑 | 職責 |
| --- | --- |
| scenes/main.tscn、scripts/main.gd | 啟動、storage、旅程、計時及存讀檔 |
| scenes/player.tscn、scripts/player.gd | CharacterBody3D、第三人稱鏡頭、WASD 與 Space 跳躍 |
| scenes/land.tscn、scripts/land.gd | 本土 64×64 平地、碰撞與 1 m 格線 |
| scenes/block_terrain.tscn、scripts/block_terrain.gd | 目前外島的高度階層、斜坡與地面碰撞 |
| scenes/island_terrain.tscn、scripts/island_terrain.gd | 平滑比較地形，共用水面與深水邊界生成 |
| shaders/island_water.gdshader | 淺深水顏色、透明度、漣漪及岸邊亮帶 |
| scripts/inventory/ | 格位資料、跨區分配、搬移、存檔解碼及測試合成 |
| scenes/ui/inventory_panel.tscn、scripts/ui/inventory_panel.gd | 背包、工具欄、合成與介面輸入 |
| scripts/interaction.gd、scenes/travel_gate.tscn | 準星射線、左右鍵分流及出入口 |
| scripts/items/、scenes/items/、items/testing/ | Item Resource、Pickup／ItemDrop、測試礦石與目標 |
| tests/ | 獨立測試腳本，與遊戲程式分開 |

## 移動與地形

- 原型移速 6 m/s、滑鼠靈敏度 0.003 rad/px、角色中心 XZ 限制 ±31.6 m；本土格線、碰撞與邊界尺寸目前需一起維護，尚未統一參數化。
- 方塊外島以 1 m 水平格、0.5 m 高度層建立高度柱外殼。cells 記錄基底高度與四方向斜坡；斜坡水平 1 m、升高 0.5 m，固定通道以外保留直角階層。未加入挖放或洞穴資料結構。
- 平滑比較地形用 1 m 網格及固定三處低丘；兩種地面都由渲染三角網格產生碰撞，避免高度外觀與碰撞分離。
- 海面 y=-0.2；方塊版淺水海床 -0.5、深水 -1 m，平滑版海床漸降；約 4 m 淺水帶外有 128 段重疊碰撞邊界。高度與寬度是試作參數，沒有游泳物理。
- Space 只在接地、可控制且捕捉游標時起跳；測試起跳速度 sqrt(2×20×0.8)，重力 20 m/s²。每物理幀清除請求，忽略按鍵重複；開背包、轉場也清除請求。
- 外島 floor_snap_length=0.6，回本土還原 0.1；提高下坡貼地距離不提供直角自動爬階能力。

## 物品、互動與 UI

- Item Resource 目前含四種開發物品：test_material、test_tool、test_pickaxe、test_stone。材料上限 99、工具上限 1；物品 ID 經目錄驗證，不信任存檔中的 stack_limit。
- PlayerStorage 為 27 格 backpack、9 格 hotbar 及選取索引。入包先補現有堆疊，再工具欄空格、最後背包空格；回傳未收數量，來源保留餘量。
- Pickup 為層 4 的漂浮 Area3D，碰觸玩家膠囊後收取；持續接觸時可重試滿包餘量。ItemDrop 共用數量方法，但無浮動／自動收取，使用層 2 與右鍵操作；目前以測試場景驗證，未額外放入主世界配置。
- 瞄準與使用射線查層 1／2，忽略玩家與漂浮 Pickup；右鍵 ItemDrop／出入口、左鍵測試工具／鎬各自驗證角色中心 3 m 與遮擋。背包、游標釋放及重捕捉事件隔離世界使用。
- test_ore 五擊產生 1＋1＋1＋1＋3 個獨立石塊，第五擊移除礦石；短暫視覺碎片不是額外物品。既有測試工具只命中測試方塊。
- 合成以 PlayerStorage 副本預扣材料並預放產物，成功才整體套用，涵蓋新四種 Item 的預檢；目前只有測試配方，不是正式通用配方系統。
- UI 以 960×540 為邏輯基準、預設視窗 1152×648、canvas_items／expand 縮放；背包與工具欄 64×64 正方形。格內省略開發用後綴，仍以文字顯示，尚無正式圖示。
- E 開關、Esc 關閉背包；關閉取消拿取，Esc 事件標記已處理，避免同次又釋放游標。背包關閉時 Esc 沿用釋放功能。
- 世界 Label3D 字級：Pickup／ItemDrop／出入口／測試方塊 48、礦石 60，pixel_size=0.004。

## 旅程與本機存檔

- 出入口 (8, 0.9, -5)，抵達點 (8, 0, -3)；測試鎬在本土 (3, 0.9, -2)，外島礦石 (3, 0.8, -8)。座標是固定測試配置。
- 外島期間將本土 Land、TestPickups、UseTestTarget、出入口及 DevSupplies 暫時移出場景樹，保留資料；回程移除外島並還原本土。每趟重建測試材料 120 與礦石，尚無隨機生成。
- user://save.cfg 採 ConfigFile 版本 2，相容版本 1 位置存檔；保存 storage、角色、鏡頭、本土兩種測試 Pickup 餘量及可選 world.test_pickaxe_remaining（0／1，舊檔缺省 1）。領取鎬後不重發。
- AutoSaveTimer 每 60 秒呼叫 _autosave，僅本土執行；外島跳過，返回按原週期恢復。正常關閉仍呼叫 save_game，成功才退出。
- 外島儲存使用本土返回落點與本土 Pickup 餘量，保留已取得物品；不保存舊島、礦石敲擊數、未拾石塊或碎片。載入位置高度恢復 y=0，不保存空中速度／跳躍狀態。
- storage 與 Pickup／鎬餘量完整驗證後才套用；資料無效時保留原檔、停止自動覆寫並提示，成功重載後恢復。仍為單檔直接寫入，沒有備份或中斷寫入復原保證。

## 限制與未決方案

- A4～A6 及 B 模組尚未實作；正式 Item／配方、地形挖放、隨機生成、多人權威、同步、離線、權限及聊天仍待確認。
- 土地在擁有者電腦、交易記於店主土地端、公司記於所在地端僅為構想，安全性與一致性尚未驗證。
- 長期存檔格式、備份、原子寫入／復原及後續功能資料相容性未定案；不因原型測試通過而宣告安全或一致性保證。
- 既往載入、視窗操作、截圖與功能測試結果及失敗紀錄見 [進度](PROGRESS.md)。使用者曾回報早期原型試玩 OK；後續地形／跳躍仍待人工回饋。本次文件整理未執行遊戲測試。
