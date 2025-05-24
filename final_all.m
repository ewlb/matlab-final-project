classdef final_all < handle
    properties
        % 遊戲狀態與視窗管理
        MainFig % 主視窗
        MainPanel % 主選單面板
        LevelPanel % 關卡選擇面板
        GamePanel % 遊戲面板
        HelpPanel % 說明面板
        PausePanel % 暫停面板 (新增)
        GameOverPanel % 遊戲結束面板 (新增)
        VictoryPanel

        CurrentPanel % 當前顯示的面板
        GameState = 'MAIN_MENU' % 遊戲狀態追蹤
        % 可能值: MAIN_MENU, LEVEL_SELECT, PLAYING, PAUSED, GAME_OVER, HELP

        % 螢幕尺寸
        ScreenWidth
        ScreenHeight
        gameWidth = 1000
        gameHeight = 700

        % 遊戲核心元素
        GameAxes
        Player
        Enemies = struct()
        Bullets = struct('Position', {}, 'Velocity', {}, 'Damage', {}, 'IsBossBullet', {}, ...
            'Graphic', {}, 'AnimationFrame', {}, 'FrameCount', {}, ...
            'AnimationTimer', {}, 'AnimationSpeed', {}, 'Angle', {}, 'Size', {})

        Timer
        MousePos = [0, 0]

        % 玩家資訊標籤
        HealthLabel
        AttackLabel

        % 遊戲設定
        isPaused = false
        AxesXLim
        AxesYLim
        CurrentLevel

        TimeLabel % 時間顯示標籤
        GameTimer % 遊戲計時器
        ElapsedTime = 0 % 累計時間(秒)
        TimeStr = '00:00' % 時間顯示字串

        BossAdded = false
        BossWarningGraphic = [] % 預警標記圖形物件
        BossWarningActive = false % 預警狀態標記
        BlinkTimer = [] % 閃爍效果計時器

        FireballFrames = {} % Store the fireball animation frames
        % 圖片的基礎路徑
        basePath = 'C:\Users\User\Desktop\matlab_\final';
        % player animation property
        IdleFrames
        RunFrames
        CurrentDirection = 3 % 1=上，2=左，3=下，4=右
        IsMoving = false
        CurrentFrame = 1
        AnimationTimer = 0
        AnimationSpeed = 0.1
        % used to fix input latency
        KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false)

        % 技能(1)
        SkillCooldown = 0 % 技能冷卻時間(秒)
        SkillMaxCooldown = 3 % 最大冷卻時間
        SkillLabel % 技能冷卻顯示標籤
        SkillEffects = {} % 存儲技能動畫效果
        SkillDescLabel % 技能說明標籤
        SkillIcon % 技能圖標
        Skill1Frames = {} % 技能1動畫幀
        Skill1Animations = {} % 技能1動畫實例

        % 技能2
        Skill2Cooldown = 0
        Skill2MaxCooldown = 4
        Skill2Label
        Skill2DescLabel
        Skill2Icon
        PoisonProjectiles = {}
        PoisonAreas = {}

        % 技能3
        Skill3Cooldown = 0
        Skill3MaxCooldown = 3
        Skill3Label
        Skill3DescLabel
        Skill3Icon
        ExplosionFrames = {}
        Skill3Animation = []

        % 敵人生成
        EnemySpawnTimer = 0 % 生成計時器
        EnemySpawnInterval = 5 % 生成間隔(秒)
        MaxEnemies = 8 % 最大敵人數量
        SpawnMargin = 50 % 在畫面邊緣外的生成邊距

    end

    methods
        function obj = final_all()
            % 創建唯一的主視窗並設置背景
            obj.MainFig = uifigure('Name', '太空射擊遊戲');
            obj.MainFig.WindowState = 'fullscreen';
            obj.MainFig.Color = [0.1, 0.1, 0.4];

            % 取得螢幕大小
            screenSize = get(0, 'ScreenSize');
            obj.ScreenWidth = screenSize(3);
            obj.ScreenHeight = screenSize(4);

            % 預加載所有面板
            obj.MainPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'on', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.LevelPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.HelpPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.VictoryPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]); % 綠色背景

            % 計算位置
            xOffset = (obj.ScreenWidth - obj.gameWidth) / 2;
            yOffset = (obj.ScreenHeight - obj.gameHeight) / 2;

            % 遊戲相關面板
            obj.GamePanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.PausePanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0, 0, 0, 0.5]);
            obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0, 0, 0, 0.8]);

            % 初始化所有面板內容
            obj.initMainMenu();
            obj.initLevelSelect();
            obj.initHelpScreen();
            obj.initPauseMenu();
            obj.initGameOverScreen();
            obj.initVictoryScreen();

            % 設置當前面板
            obj.CurrentPanel = obj.MainPanel;

            % 設置窗口關閉時的清理函數
            obj.MainFig.CloseRequestFcn = @(src, event) obj.cleanup();
        end

        function cleanup(obj)
            % 停止並刪除定時器
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                try
                    stop(obj.Timer);
                    delete(obj.Timer);
                catch
                    % 忽略錯誤
                end
            end

            % 清理遊戲資源
            obj.cleanupGameState();

            % 關閉視窗
            delete(obj.MainFig);
        end

        % 狀態管理核心函數
        function switchPanel(obj, panelName)

            % 共通的狀態轉換處理
            obj.handleStateTransition(obj.GameState, panelName);

            % 隱藏當前面板
            obj.CurrentPanel.Visible = 'off';

            % 顯示目標面板
            switch panelName
                case 'main'
                    obj.cleanupGameState();
                    obj.CurrentPanel = obj.MainPanel;
                    obj.GameState = 'MAIN_MENU';
                case 'level'
                    obj.CurrentPanel = obj.LevelPanel;
                    obj.GameState = 'LEVEL_SELECT';
                case 'game'
                    obj.CurrentPanel = obj.GamePanel;
                    obj.GameState = 'PLAYING';
                case 'pause'
                    obj.CurrentPanel = obj.PausePanel;
                    obj.GameState = 'PAUSED';
                case 'gameover'
                    obj.CurrentPanel = obj.GameOverPanel;
                    obj.GameState = 'GAME_OVER';
                case 'help'
                    obj.CurrentPanel = obj.HelpPanel;
                    obj.GameState = 'HELP';
            end

            % 確保新面板有效
            if isvalid(obj.CurrentPanel)
                obj.CurrentPanel.Visible = 'on';
                drawnow;
            end
        end

        % 狀態轉換處理
        function handleStateTransition(obj, fromState, toPanel)

            % 從遊戲中轉移到其他面板
            if strcmp(fromState, 'PLAYING') && ~strcmp(toPanel, 'game') && ~strcmp(toPanel, 'pause') && ~strcmp(toPanel, 'gameover')
                % 離開遊戲時，停止計時器並清理資源
                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    try
                        stop(obj.Timer);
                        delete(obj.Timer);
                    catch
                        % 忽略錯誤
                    end
                    obj.Timer = [];
                end
                obj.cleanupGameState();
            end

            % 從暫停狀態轉移
            if strcmp(toPanel, 'game')
                % 從暫停返回遊戲，重啟計時器
                if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                    start(obj.Timer);
                end
            end
            % 從遊戲結束狀態轉移
            if strcmp(fromState, 'GAME_OVER')
                % 離開遊戲結束畫面時，確保徹底清理
                fprintf('test')
                obj.isPaused = false;
            end
        end


        % 遊戲關卡控制
        function startLevel(obj, levelNum)
            % 重置遊戲狀態
            obj.GameState = 'PLAYING';
            obj.CurrentLevel = levelNum;
            obj.isPaused = false;

            % 確保舊的遊戲元素被清理
            obj.cleanupGameState();

            % 初始化遊戲畫面
            obj.initGameScreen(levelNum);
            obj.switchPanel('game');
            % 重置計時器狀態
            obj.ElapsedTime = 0;
            obj.TimeStr = '00:00';
            obj.TimeLabel.Text = obj.TimeStr;

            % 創建遊戲計時器（與現有遊戲循環計時器分離）
            obj.GameTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1, ...
                'TimerFcn', @(src, event) obj.updateTimer(), ...
                'BusyMode', 'drop');
            start(obj.GameTimer);
        end

        % 暫停功能
        function togglePause(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')

                obj.isPaused = true;

                % 重置所有按鍵
                obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
                obj.IsMoving = false;

                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                end
                obj.switchPanel('pause');

            elseif obj.isPaused && strcmp(obj.GameState, 'PAUSED')
                % 恢復遊戲
                obj.isPaused = false;
                obj.switchPanel('game');
                if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                    start(obj.Timer); % 只有計時器未運行時才啟動
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    start(obj.GameTimer);
                end
            end
        end


        function quitGame(obj)
            obj.cleanup();
        end

        function trackMousePosition(obj)
            % 只在遊戲面板可見時更新滑鼠位置
            if strcmp(obj.GameState, 'PLAYING') && isvalid(obj.GameAxes)
                cp = obj.GameAxes.CurrentPoint;
                obj.MousePos = cp(1, 1:2);
            end
        end

        function handleMouseClick(obj)
            % 只處理左鍵點擊且遊戲未暫停時
            if strcmp(obj.GameState, 'PLAYING') && ~obj.isPaused && strcmp(obj.MainFig.SelectionType, 'normal')
                % 計算發射方向
                direction = obj.MousePos - obj.Player.Position;

                % 標準化方向向量
                if norm(direction) > 0
                    direction = direction / norm(direction);

                    % 創建並發射子彈
                    obj.fireBullet(obj.Player.Position, direction, false, obj.Player.Attack);
                end
            end
        end

        function gameLoop(obj)
            try
                % 只在遊戲狀態且非暫停時執行
                if strcmp(obj.GameState, 'PLAYING') && ~obj.isPaused
                    % 檢查玩家圖形是否有效
                    if ~isfield(obj.Player, 'Graphic') || ~isvalid(obj.Player.Graphic)
                        % 重建玩家圖形
                        obj.Player.Graphic = rectangle(obj.GameAxes, 'Position', [0, 0, 30, 30], ...
                            'FaceColor', 'b');
                        updatePosition(obj.Player.Graphic, obj.Player.Position);
                    end

                    % 檢查敵人圖形是否有效
                    for i = 1:length(obj.Enemies)
                        if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
                            % 根據敵人類型重建圖形
                            if strcmp(obj.Enemies(i).Type, 'boss')
                                % 特殊處理BOSS圖形
                                obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                                    'Position', [0, 0, 60, 60], ... % 更大尺寸
                                    'FaceColor', [1, 0, 1], ... % 洋紅色
                                    'Curvature', 0.3); % 圓角矩形
                            else
                                % 普通敵人圖形
                                obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                                    'Position', [0, 0, 30, 30], ...
                                    'FaceColor', 'r');
                            end
                            updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                        end
                    end

                    % 更新遊戲邏輯
                    obj.updatePlayerMovement();
                    obj.updateBullets();
                    obj.checkBulletCollisions();
                    obj.updateEnemies();
                    obj.resolveEnemyCollisions();
                    obj.checkPlayerEnemyCollision();
                    obj.updatePlayerAnimation(0.016);

                    obj.updateSkillSystem(0.016);
                    obj.updateSkillUI();
                    % skill_2
                    obj.updatePoisonProjectiles(0.016);
                    obj.updatePoisonAreas(0.016);
                    obj.updateSkill2UI();
                    % skill_3
                    obj.updateSkill3Animation(0.016);
                    obj.updateSkill3UI();

                    % 敵人生成
                    obj.updateEnemySpawning(0.016);

                    % 更新玩家資訊顯示
                    if isvalid(obj.HealthLabel)
                        obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
                    end
                    if isvalid(obj.AttackLabel)
                        obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
                    end

                    % 檢查玩家是否死亡
                    if obj.Player.Health <= 0
                        fprintf('Player died! Health: %d\n', obj.Player.Health); % 添加調試輸出
                        obj.showGameOverScreen();
                        return;
                    end
                    drawnow limitrate;
                end
            catch ME
                disp(['遊戲循環錯誤: ', ME.message]);
                disp(getReport(ME));
            end
        end

        function updatePlayerMovement(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                speed = 5;
                originalPos = obj.Player.Position;
                newPos = originalPos;
                moved = false;

                % 根據按鍵狀態更新位置
                if obj.KeysPressed.w
                    newPos(2) = min(obj.gameHeight-30, originalPos(2)+speed);
                    moved = true;
                end
                if obj.KeysPressed.s
                    newPos(2) = max(30, originalPos(2)-speed);
                    moved = true;
                end
                if obj.KeysPressed.a
                    newPos(1) = max(30, originalPos(1)-speed);
                    moved = true;
                end
                if obj.KeysPressed.d
                    newPos(1) = min(obj.gameWidth-30, originalPos(1)+speed);
                    moved = true;
                end

                % 只有在實際移動時才更新IsMoving狀態
                obj.IsMoving = moved;

                % 檢查碰撞
                if moved
                    canMove = true;

                    % 敵人碰撞檢測...
                    if isfield(obj, 'Enemies') && ~isempty(obj.Enemies)
                        for i = 1:length(obj.Enemies)
                            if isfield(obj.Enemies(i), 'Position')
                                if obj.checkAABBCollision(newPos, obj.Player.Size, obj.Enemies(i).Position, 30)
                                    canMove = false;
                                    break;
                                end
                            end
                        end
                    end

                    % 只有在不碰撞時才移動
                    if canMove
                        obj.Player.Position = newPos;
                        obj.updatePlayerPosition();
                    end
                end
            end
        end

        function updatePlayerAnimation(obj, deltaTime)
            % 更新動畫計時器
            obj.AnimationTimer = obj.AnimationTimer + deltaTime;

            % 時間到達後切換幀
            if obj.AnimationTimer >= obj.AnimationSpeed
                obj.AnimationTimer = 0;

                if obj.IsMoving
                    % 運行動畫 - 循環切換8幀
                    totalFrames = 8; % run.png 每個方向有8幀
                    obj.CurrentFrame = mod(obj.CurrentFrame, totalFrames) + 1;

                    % 獲取當前方向的當前運行幀
                    frame = obj.RunFrames{obj.CurrentDirection, obj.CurrentFrame};
                else
                    % 靜止動畫 - 使用對應方向的靜止幀
                    frame = obj.IdleFrames{obj.CurrentDirection};
                end

                % 更新角色圖形
                if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                    obj.Player.Graphic.CData = frame.Image;
                    obj.Player.Graphic.AlphaData = frame.Alpha;
                end
            end
        end


        % 顯示遊戲結束畫面
        function showGameOverScreen(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.isPaused = true;

                % 重置按鍵狀態
                obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
                obj.IsMoving = false;

                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                end
                obj.switchPanel('gameover');
            end
        end


        function retry(obj)

            obj.startLevel(obj.CurrentLevel);
            % delete(obj.Timer);
            % obj.Timer = [];

        end

        % 碰撞檢測
        function collision = checkAABBCollision(obj, pos1, size1, pos2, size2)
            % AABB 碰撞檢測
            halfSize1 = size1 / 2;
            halfSize2 = size2 / 2;

            collision = abs(pos1(1)-pos2(1)) < (halfSize1 + halfSize2) && ...
                abs(pos1(2)-pos2(2)) < (halfSize1 + halfSize2);
        end

        function startBlink(obj)
            % 停止現有計時器
            if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
                stop(obj.BlinkTimer);
                delete(obj.BlinkTimer);
            end

            % 創建新計時器
            obj.BlinkTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TasksToExecute', 6, ... % 閃爍3秒=6*0.5
                'TimerFcn', @(src, event) obj.toggleBlink());

            start(obj.BlinkTimer);
        end

        function toggleBlink(obj)
            if isvalid(obj.BossWarningGraphic)
                if (obj.BossWarningGraphic.FaceAlpha < 0.5)
                    obj.BossWarningGraphic.FaceAlpha = 0.8;
                else
                    obj.BossWarningGraphic.FaceAlpha = 0.4;
                end
            end
        end

        function initMainMenu(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            % 遊戲標題
            titleLbl = uilabel(obj.MainPanel);
            titleLbl.Text = '太空射擊戰';
            titleLbl.FontSize = 48;
            titleLbl.FontColor = 'w';
            titleLbl.Position = [centerX - 200, centerY + 150, 400, 60];

            % 遊戲開始按鈕
            startBtn = uibutton(obj.MainPanel, 'push');
            startBtn.Text = '開始遊戲';
            startBtn.Position = [centerX - 100, centerY, 200, 60];
            startBtn.FontSize = 24;
            startBtn.BackgroundColor = [0.2, 0.6, 1];
            startBtn.FontColor = 'w';
            startBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('level');

            % 遊戲說明按鈕
            helpBtn = uibutton(obj.MainPanel, 'push');
            helpBtn.Text = '遊戲說明';
            helpBtn.Position = [centerX - 100, centerY - 100, 200, 60];
            helpBtn.FontSize = 24;
            helpBtn.BackgroundColor = [0.2, 0.6, 1];
            helpBtn.FontColor = 'w';
            helpBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('help');
        end
        function initHelpScreen(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            % 說明標題
            titleLbl = uilabel(obj.HelpPanel);
            titleLbl.Text = '遊戲說明';
            titleLbl.FontSize = 36;
            titleLbl.FontColor = 'w';
            titleLbl.Position = [centerX - 100, centerY + 200, 200, 40];

            % 基本操作說明
            basicControlLbl = uilabel(obj.HelpPanel);
            basicControlLbl.Text = '基本操作';
            basicControlLbl.FontSize = 24;
            basicControlLbl.FontColor = [1, 1, 0]; % 黃色標題
            basicControlLbl.Position = [centerX - 200, centerY + 150, 150, 30];

            % 基本操作內容
            instructLbl = uilabel(obj.HelpPanel);
            instructLbl.Text = sprintf('%s\n%s\n%s', '移動: WASD鍵', '射擊: 滑鼠左鍵', '暫停: P鍵');
            instructLbl.WordWrap = 'on';
            instructLbl.FontSize = 18;
            instructLbl.FontColor = 'w';
            instructLbl.Position = [centerX - 200, centerY + 80, 400, 80];

            % 技能說明標題
            skillTitleLbl = uilabel(obj.HelpPanel);
            skillTitleLbl.Text = '技能系統';
            skillTitleLbl.FontSize = 24;
            skillTitleLbl.FontColor = [1, 1, 0]; % 黃色標題
            skillTitleLbl.Position = [centerX - 200, centerY + 30, 150, 30];

            % 技能1說明
            skill1Lbl = uilabel(obj.HelpPanel);
            skill1Lbl.Text = '技能1 (按鍵1): 範圍傷害';
            skill1Lbl.FontSize = 16;
            skill1Lbl.FontColor = [0.8, 1, 0.8]; % 淺綠色
            skill1Lbl.Position = [centerX - 200, centerY - 10, 400, 25];

            skill1DetailLbl = uilabel(obj.HelpPanel);
            skill1DetailLbl.Text = '在鼠標位置造成1.5倍攻擊力的範圍傷害，冷卻3秒';
            skill1DetailLbl.FontSize = 14;
            skill1DetailLbl.FontColor = 'w';
            skill1DetailLbl.Position = [centerX - 180, centerY - 35, 400, 20];

            % 技能2說明
            skill2Lbl = uilabel(obj.HelpPanel);
            skill2Lbl.Text = '技能2 (按鍵2): 毒藥水';
            skill2Lbl.FontSize = 16;
            skill2Lbl.FontColor = [0.8, 1, 0.8]; % 淺綠色
            skill2Lbl.Position = [centerX - 200, centerY - 65, 400, 25];

            skill2DetailLbl = uilabel(obj.HelpPanel);
            skill2DetailLbl.Text = '投擲毒藥水，在目標位置生成持續傷害區域並減速敵人，冷卻4秒';
            skill2DetailLbl.FontSize = 14;
            skill2DetailLbl.FontColor = 'w';
            skill2DetailLbl.Position = [centerX - 180, centerY - 90, 400, 20];

            % 技能3說明
            skill3Lbl = uilabel(obj.HelpPanel);
            skill3Lbl.Text = '技能3 (按鍵3): 超級大爆炸';
            skill3Lbl.FontSize = 16;
            skill3Lbl.FontColor = [1, 0.5, 0.5]; % 淺紅色 - 表示終極技能
            skill3Lbl.Position = [centerX - 200, centerY - 120, 400, 25];

            skill3DetailLbl = uilabel(obj.HelpPanel);
            skill3DetailLbl.Text = '消滅畫面上所有敵人的終極技能，冷卻3秒';
            skill3DetailLbl.FontSize = 14;
            skill3DetailLbl.FontColor = 'w';
            skill3DetailLbl.Position = [centerX - 180, centerY - 145, 400, 20];

            % 遊戲提示
            tipTitleLbl = uilabel(obj.HelpPanel);
            tipTitleLbl.Text = '遊戲提示';
            tipTitleLbl.FontSize = 20;
            tipTitleLbl.FontColor = [1, 1, 0]; % 黃色標題
            tipTitleLbl.Position = [centerX - 200, centerY - 185, 150, 30];

            tipLbl = uilabel(obj.HelpPanel);
            tipLbl.Text = sprintf('%s\n', ...
                '• 滑鼠在不同位置點擊可以射很快');
            tipLbl.WordWrap = 'on';
            tipLbl.FontSize = 14;
            tipLbl.FontColor = 'w';
            tipLbl.Position = [centerX - 180, centerY - 250, 400, 60];

            % 返回按鈕
            backBtn = uibutton(obj.HelpPanel, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Position = [centerX - 100, centerY - 300, 200, 50];
            backBtn.FontSize = 18;
            backBtn.BackgroundColor = [0.8, 0.2, 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('main');
        end

        function initLevelSelect(obj)
            % 主網格佈局
            mainGrid = uigridlayout(obj.LevelPanel, [3, 1]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.BackgroundColor = [0.1, 0.1, 0.4];

            % 標題區域
            titleLbl = uilabel(mainGrid);
            titleLbl.Text = '選擇關卡';
            titleLbl.FontSize = 36;
            titleLbl.FontColor = 'w';
            titleLbl.HorizontalAlignment = 'center';
            titleLbl.Layout.Row = 1;
            titleLbl.Layout.Column = 1;

            % 關卡按鈕容器
            btnGrid = uigridlayout(mainGrid, [1, 3]);
            btnGrid.Padding = [50, 0, 50, 0];
            btnGrid.Layout.Row = 2;
            btnGrid.Layout.Column = 1;
            btnGrid.BackgroundColor = [0.1, 0.1, 0.4];

            % 三個關卡按鈕
            for i = 1:3
                btn = uibutton(btnGrid, 'push');
                btn.Text = sprintf('第 %d 關', i);
                btn.FontSize = 24;
                btn.BackgroundColor = [0.3, 0.7, 0.5];
                btn.FontColor = 'w';
                btn.ButtonPushedFcn = @(src, event) obj.startLevel(i);
            end

            % % 返回按鈕區域
            backGrid = uigridlayout(mainGrid, [1, 3]);
            backGrid.Padding = [0, 100, 0, 100];
            backGrid.BackgroundColor = [0.1, 0.1, 0.4];
            backGrid.Layout.Row = 3;
            backGrid.Layout.Column = 1;

            backBtn = uibutton(backGrid, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Layout.Column = 2; % important
            backBtn.FontSize = 1 * -1 + 45 - 14; % 30
            backBtn.BackgroundColor = [0.8, 0.2, 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('main');


        end
        function initGameScreen(obj, levelNum)
            % 清理舊的遊戲元素
            obj.cleanupGameState();
            delete(findobj(obj.GamePanel, 'Type', 'UIAxes'));

            % 創建遊戲畫布
            obj.GameAxes = uiaxes(obj.GamePanel);
            obj.GameAxes.Position = [0, 0, obj.gameWidth, obj.gameHeight];

            % 更新遊戲限制範圍
            obj.AxesXLim = [0, obj.gameWidth];
            obj.AxesYLim = [0, obj.gameHeight];

            % 設定固定顯示範圍
            axis(obj.GameAxes, 'equal');
            xlim(obj.GameAxes, obj.AxesXLim);
            ylim(obj.GameAxes, obj.AxesYLim);
            hold(obj.GameAxes, 'on');
            set(obj.GameAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');

            % 禁用默認交互
            disableDefaultInteractivity(obj.GameAxes);
            obj.GameAxes.Interactions = [];
            obj.GameAxes.Toolbar = [];

            % 暫停按鈕
            pauseBtn = uibutton(obj.GamePanel, 'push');
            pauseBtn.Text = '⏸';
            pauseBtn.Position = [obj.gameWidth - 70, obj.gameHeight - 50, 40, 40];
            pauseBtn.FontSize = 24;
            pauseBtn.BackgroundColor = [0.9, 0.9, 0.9];
            pauseBtn.ButtonPushedFcn = @(src, event) obj.togglePause();

            % 設置控制監聽
            set(obj.MainFig, 'KeyPressFcn', @(src, event) obj.handleKeyPress(event));
            set(obj.MainFig, 'KeyReleaseFcn', @(src, event) obj.handleKeyRelease(event));
            set(obj.MainFig, 'WindowButtonMotionFcn', @(src, event) obj.trackMousePosition());
            set(obj.MainFig, 'WindowButtonDownFcn', @(src, event) obj.handleMouseClick());

            % 初始化遊戲元素
            obj.initPlayer();
            obj.initEnemies(levelNum);
            % 根據關卡調整生成參數
            switch levelNum
                case 1
                    obj.EnemySpawnInterval = 1; % todo: modify
                    obj.MaxEnemies = 10;
                case 2
                    obj.EnemySpawnInterval = 6;
                    obj.MaxEnemies = 15;
                case 3
                    obj.EnemySpawnInterval = 4;
                    obj.MaxEnemies = 20;
            end

            % 重置生成計時器
            obj.EnemySpawnTimer = 0;

            % 添加時間標籤
            obj.TimeLabel = uilabel(obj.MainFig);
            obj.TimeLabel.Text = '時間: 00:00';
            obj.TimeLabel.Position = [50, obj.ScreenHeight - 50, 200, 30];
            obj.TimeLabel.FontSize = 18;
            obj.TimeLabel.FontColor = 'w';
            obj.TimeLabel.BackgroundColor = [0.1, 0.1, 0.4];


            % 創建玩家標籤
            obj.HealthLabel = uilabel(obj.MainFig);
            obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
            obj.HealthLabel.Position = [50, obj.ScreenHeight - 100, 200, 30];
            obj.HealthLabel.FontSize = 18;
            obj.HealthLabel.FontColor = 'w';
            obj.HealthLabel.BackgroundColor = [0.1, 0.1, 0.4];

            obj.AttackLabel = uilabel(obj.MainFig);
            obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
            obj.AttackLabel.Position = [50, obj.ScreenHeight - 150, 200, 30];
            obj.AttackLabel.FontSize = 18;
            obj.AttackLabel.FontColor = 'w';
            obj.AttackLabel.BackgroundColor = [0.1, 0.1, 0.4];

            % skill_1
            obj.SkillIcon = uiimage(obj.MainFig);
            obj.SkillIcon.ImageSource = 'C:\Users\User\Desktop\matlab_\final\images\skill\mikunani.png';
            obj.SkillIcon.Position = [65, obj.ScreenHeight - 200, 30, 30]; % 調整大小和位置
            obj.SkillIcon.Visible = 'off'; % 初始隱藏

            obj.SkillLabel = uilabel(obj.MainFig);
            obj.SkillLabel.Text = '';
            obj.SkillLabel.Position = [50, obj.ScreenHeight - 200, 80, 40];
            obj.SkillLabel.FontSize = 18;
            obj.SkillLabel.FontColor = 'w';
            obj.SkillLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.SkillLabel.HorizontalAlignment = 'center';
            obj.SkillLabel.Visible = 'off';


            obj.SkillDescLabel = uilabel(obj.MainFig);
            obj.SkillDescLabel.Text = '技能(1)';
            obj.SkillDescLabel.Position = [135, obj.ScreenHeight - 200, 100, 40];
            obj.SkillDescLabel.FontSize = 14;
            obj.SkillDescLabel.FontColor = 'w';
            obj.SkillDescLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.loadSkill1Frames();


            % 技能2
            obj.Skill2Icon = uiimage(obj.MainFig);
            obj.Skill2Icon.ImageSource = 'C:\Users\User\Desktop\matlab_\final\images\skill\mikunani.png';
            obj.Skill2Icon.Position = [65, obj.ScreenHeight - 250, 30, 30];
            obj.Skill2Icon.Visible = 'off';

            obj.Skill2Label = uilabel(obj.MainFig);
            obj.Skill2Label.Text = '';
            obj.Skill2Label.Position = [50, obj.ScreenHeight - 250, 80, 40];
            obj.Skill2Label.FontSize = 18;
            obj.Skill2Label.FontColor = 'w';
            obj.Skill2Label.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill2Label.HorizontalAlignment = 'center';
            obj.Skill2Label.Visible = 'off';

            obj.Skill2DescLabel = uilabel(obj.MainFig);
            obj.Skill2DescLabel.Text = '技能(2)';
            obj.Skill2DescLabel.Position = [135, obj.ScreenHeight - 250, 100, 40];
            obj.Skill2DescLabel.FontSize = 14;
            obj.Skill2DescLabel.FontColor = 'w';
            obj.Skill2DescLabel.BackgroundColor = [0.1, 0.1, 0.4];

            % skill3
            % 第三個技能 - 添加在第二個技能下方
            obj.Skill3Icon = uiimage(obj.MainFig);
            obj.Skill3Icon.ImageSource = 'C:\Users\User\Desktop\matlab_\final\images\skill\mikunani.png';
            obj.Skill3Icon.Position = [65, obj.ScreenHeight - 300, 30, 30];
            obj.Skill3Icon.Visible = 'off';

            obj.Skill3Label = uilabel(obj.MainFig);
            obj.Skill3Label.Text = '';
            obj.Skill3Label.Position = [50, obj.ScreenHeight - 300, 80, 40];
            obj.Skill3Label.FontSize = 18;
            obj.Skill3Label.FontColor = 'w';
            obj.Skill3Label.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill3Label.HorizontalAlignment = 'center';
            obj.Skill3Label.Visible = 'off';

            obj.Skill3DescLabel = uilabel(obj.MainFig);
            obj.Skill3DescLabel.Text = '技能(3)';
            obj.Skill3DescLabel.Position = [135, obj.ScreenHeight - 300, 100, 40];
            obj.Skill3DescLabel.FontSize = 14;
            obj.Skill3DescLabel.FontColor = 'w';
            obj.Skill3DescLabel.BackgroundColor = [0.1, 0.1, 0.4];
            % 載入爆炸動畫幀
            obj.loadExplosionFrames();


            obj.FireballFrames = cell(1, 5);
            for i = 1:5
                try
                    % Load fireball image
                    % 構建完整的圖片路徑
                    imagePath = fullfile(obj.basePath, 'images', 'FB00', sprintf('FB00%d.png', i));

                    [img, map, alpha] = imread(imagePath);
                    img = ind2rgb(img, map); % 轉換為雙精度，保持色彩一致性
                    obj.FireballFrames{i} = struct('Image', img, 'Alpha', alpha);
                catch e
                    warning('Failed to load fireball image %d: %s', i, e.message);
                    % Create a fallback orange circle as fireball
                    img = ones(30, 30, 3, 'uint8');
                    img(:, :, 1) = 255; % Red
                    img(:, :, 2) = 165; % Green (make orange)
                    img(:, :, 3) = 0; % Blue
                    obj.FireballFrames{i} = struct('Image', img, 'Alpha', []);
                end
            end

            % 確保計時器處於運行狀態
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016, ...
                    'TimerFcn', @(src, event) obj.gameLoop());
            end

            if strcmp(get(obj.Timer, 'Running'), 'off')
                start(obj.Timer);
            end
        end
        % 初始化暫停選單（新增）
        function initPauseMenu(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            menuContainer = uipanel(obj.PausePanel, ...
                'Position', [(obj.gameWidth - 300) / 2, (obj.gameHeight - 300) / 2, 300, 300], ...
                'BackgroundColor', [0.3, 0.3, 0.3]);

            % 暫停標籤
            uilabel(menuContainer, ...
                'Text', '遊戲已暫停', ...
                'Position', [50, 250, 200, 40], ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 繼續按鈕
            resumeBtn = uibutton(menuContainer, 'push', ...
                'Text', '繼續遊戲', ...
                'Position', [50, 200, 200, 60], ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.togglePause(), ...
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(menuContainer, 'push', ...
                'Text', '返回主畫面', ...
                'Position', [50, 110, 200, 60], ...
                'BackgroundColor', [0.2, 0.2, 0.6], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(menuContainer, 'push', ...
                'Text', '離開遊戲', ...
                'Position', [50, 20, 200, 60], ...
                'BackgroundColor', [0.6, 0.2, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                btnStyle{:});
        end
        %  modify from initpausemenu
        function initGameOverScreen(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            gameOverContainer = uipanel(obj.GameOverPanel, ...
                'Position', [(obj.gameWidth - 300) / 2, (obj.gameHeight - 300) / 2, 300, 300], ...
                'BackgroundColor', [0.3, 0.3, 0.3]);

            % 暫停標籤
            uilabel(gameOverContainer, ...
                'Text', 'YOU ARE SO DEAD', ...
                'Position', [0, 250, 300, 40], ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 重新按鈕
            retryBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '重玩', ...
                'Position', [50, 200, 200, 60], ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.retry(), ...
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '返回主畫面', ...
                'Position', [50, 110, 200, 60], ...
                'BackgroundColor', [0.2, 0.2, 0.6], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '離開遊戲', ...
                'Position', [50, 20, 200, 60], ...
                'BackgroundColor', [0.6, 0.2, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                btnStyle{:});
        end
        function initVictoryScreen(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            vicLbl = uilabel(obj.VictoryPanel);
            vicLbl.Text = 'victory!!!';
            vicLbl.FontSize = 48;
            vicLbl.FontColor = 'w';
            vicLbl.Position = [centerX - 100, centerY + 150, 200, 100];
            vicLbl.HorizontalAlignment = 'center'; % maybe unnecessary

            % 按鈕基礎樣式
            btnStyle = {; ...
                'FontSize', 24, ...
                'BackgroundColor', [0.2, 0.6, 1], ... % 主畫面按鈕藍色
                'FontColor', 'w'};

            % 選擇關卡按鈕
            levelBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '選擇關卡', ...
                'Position', [centerX - 100, centerY, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('level'), ...
                btnStyle{:});

            % 返回主畫面按鈕
            mainBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '主畫面', ...
                'Position', [centerX - 100, centerY - 100, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 退出遊戲按鈕(紅色突出)
            quitBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '退出遊戲', ...
                'Position', [centerX - 100, centerY - 200, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'BackgroundColor', [0.8, 0.2, 0.2]); % 紅色
        end
        function initPlayer(obj)
            % 玩家角色初始化
            obj.Player = struct( ...
                'Position', [400, 50], ...
                'Size', 30, ...
                'Health', 1314, ...
                'Attack', 520, ...
                'Graphic', []);
            obj.loadPlayerAnimations();

            % 如果動畫載入失敗，使用原有的矩形
            if ~isempty(obj.IdleFrames)
                initialFrame = obj.IdleFrames{3}; % 向下idle
                width = 60; % 跟 updatePlayerPosition 一起改
                height = 60;
                obj.Player.Graphic = image(obj.GameAxes, ...
                    'CData', initialFrame.Image, ...
                    'AlphaData', initialFrame.Alpha, ...
                    'XData', [obj.Player.Position(1) - width / 2, obj.Player.Position(1) + width / 2], ...
                    'YData', [obj.Player.Position(2) - height / 2, obj.Player.Position(2) + height / 2]);
            else
                % 備用方案 - 藍色矩形
                obj.Player.Graphic = rectangle(obj.GameAxes, 'Position', [0, 0, 30, 30], ...
                    'FaceColor', 'b');
            end
            % 重置玩家狀態
            obj.CurrentDirection = 3; % 預設向下
            obj.IsMoving = false;
            obj.CurrentFrame = 1;
            obj.AnimationTimer = 0;

            % 重置按鍵狀態
            obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
            % 更新位置
            obj.updatePlayerPosition();
        end

        function updatePlayerPosition(obj)
            if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                if ~isempty(obj.IdleFrames) & ~isempty(obj.RunFrames)
                    % 使用圖像動畫時的更新
                    width = 60; % TODO:根據實際需要調整
                    height = 60;
                    obj.Player.Graphic.XData = [obj.Player.Position(1) - width / 2, obj.Player.Position(1) + width / 2];
                    obj.Player.Graphic.YData = [obj.Player.Position(2) - height / 2, obj.Player.Position(2) + height / 2];
                else
                    % 使用矩形時的原有更新
                    updatePosition(obj.Player.Graphic, obj.Player.Position);
                end
            end
        end

        function initEnemies(obj, levelNum)
            obj.Enemies = struct('Type', {}, 'Position', {}, ...
                'Health', {}, 'Attack', {}, 'AttackRange', {}, ...
                'AttackCooldown', {}, 'SkillCooldown', {}, ...
                'SkillMaxCooldown', {}, 'SkillWarning', {}, ...
                'SkillWarningTimer', {}, 'PoisonSlowed', {}, ...
                'SlowTimer', {}, 'Graphic', {});

            switch levelNum
                case 1
                    % 近戰敵人配置
                    for i = 1:3
                        obj.Enemies(i) = struct( ...
                            'Type', 'melee', ...
                            'Position', [randi([50, 750]), 550], ...
                            'Health', 1314, ...
                            'Attack', 520, ...
                            'AttackRange', 50, ...
                            'AttackCooldown', 0, ...
                            'SkillCooldown', 0, ...
                            'SkillMaxCooldown', 0, ...
                            'SkillWarning', [], ...
                            'SkillWarningTimer', 0, ...
                            'PoisonSlowed', false, ...
                            'SlowTimer', 0, ...
                            'Graphic', [] ...
                            );

                        % 創建圖形
                        obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                            'Position', [0, 0, 30, 30], 'FaceColor', 'r');
                        updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                    end
            end
        end

        function initBOSS(obj)
            % 創建 BOSS 數據結構
            newBoss = struct( ...
                'Type', 'boss', ...
                'Position', [obj.gameWidth / 2, obj.gameHeight - 100], ...
                'Health', 100, ...
                'Attack', 100, ...
                'AttackRange', 114514, ... % Subscripted assignment between dissimilar structures
                'AttackCooldown', 0, ...
                'SkillCooldown', 0, ... % 技能冷卻
                'SkillMaxCooldown', 2, ... % boss技能冷卻為2秒
                'SkillWarning', [], ... % 技能警示圖形
                'SkillWarningTimer', 0, ... % 警示計時器
                'PoisonSlowed', false, ... % only to match structure
                'SlowTimer', 0, ...
                'Graphic', [] ...
                );

            % 創建 BOSS 圖形
            newBoss.Graphic = rectangle(obj.GameAxes, ...
                'Position', [0, 0, 60, 60], ... % 更大尺寸
                'FaceColor', [1, 0, 1], ... % 洋紅色
                'Curvature', 0.3); % 圓角矩形

            % 加入敵人陣列
            if isempty(obj.Enemies)
                obj.Enemies = newBoss;
            else
                obj.Enemies(end+1) = newBoss;
            end

            % 更新標記
            obj.BossAdded = true;
            fprintf('BOSS 已登場！\n'); % 調試用輸出
            updatePosition(newBoss.Graphic, newBoss.Position);
        end

        function handleKeyPress(obj, event)
            % 暫停切換
            if strcmp(event.Key, 'p')
                currentState = obj.MainFig.WindowState;
                obj.togglePause();
                obj.MainFig.WindowState = currentState;
                return;
            end

            if strcmp(event.Key, '1') && ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.useSkill();
                return;
            end

            if strcmp(event.Key, '2') && ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.useSkill2();
                return;
            end

            if strcmp(event.Key, '3') && ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.useSkill3();
                return;
            end


            % 遊戲進行中才處理移動
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                % 更新按鍵狀態
                if ismember(event.Key, {'w', 'a', 's', 'd'})
                    obj.KeysPressed.(event.Key) = true;

                    % 設置移動狀態和方向
                    obj.IsMoving = true;
                    switch event.Key
                        case 'w', obj.CurrentDirection = 1; % 上
                        case 'a', obj.CurrentDirection = 2; % 左
                        case 's', obj.CurrentDirection = 3; % 下
                        case 'd', obj.CurrentDirection = 4; % 右
                    end
                end
            end
        end

        function updateBullets(obj)
            % 若無子彈則跳過
            if isempty(obj.Bullets)
                return;
            end

            % 用於標記要刪除的子彈
            bulletsToRemove = false(1, length(obj.Bullets));

            % 遍歷所有子彈
            for i = 1:length(obj.Bullets)
                obj.Bullets(i).Position = obj.Bullets(i).Position + obj.Bullets(i).Velocity;
                if obj.Bullets(i).IsBossBullet && isfield(obj.Bullets(i), 'AnimationFrame')
                    % Update fireball animation
                    try
                        % Get current size
                        w = diff(obj.Bullets(i).Graphic.XData);
                        h = diff(obj.Bullets(i).Graphic.YData);


                        % Update position
                        obj.Bullets(i).Graphic.XData = [obj.Bullets(i).Position(1) - w / 2, obj.Bullets(i).Position(1) + w / 2];
                        obj.Bullets(i).Graphic.YData = [obj.Bullets(i).Position(2) - h / 2, obj.Bullets(i).Position(2) + h / 2];

                        % Update animation frame
                        obj.Bullets(i).AnimationTimer = obj.Bullets(i).AnimationTimer + 0.016; % Assuming 60 FPS
                        if obj.Bullets(i).AnimationTimer >= obj.Bullets(i).AnimationSpeed
                            % Reset timer
                            obj.Bullets(i).AnimationTimer = 0;

                            % Advance frame
                            obj.Bullets(i).AnimationFrame = mod(obj.Bullets(i).AnimationFrame, obj.Bullets(i).FrameCount) + 1;

                            % Get next frame and rotate it
                            frame = obj.FireballFrames{obj.Bullets(i).AnimationFrame};
                            img = frame.Image;
                            alpha = frame.Alpha;

                            % Rotate image for direction
                            rotatedImg = imrotate(img, -obj.Bullets(i).Angle, 'bicubic');
                            if ~isempty(alpha)
                                rotatedAlpha = imrotate(alpha, -obj.Bullets(i).Angle, 'bicubic');
                                obj.Bullets(i).Graphic.AlphaData = rotatedAlpha;
                            end

                            % Update image
                            obj.Bullets(i).Graphic.CData = rotatedImg;

                            % Recalculate size and position after rotation
                            [h, w, ~] = size(rotatedImg);
                            obj.Bullets(i).Graphic.XData = [obj.Bullets(i).Position(1) - w / 2, obj.Bullets(i).Position(1) + w / 2];
                            obj.Bullets(i).Graphic.YData = [obj.Bullets(i).Position(2) - h / 2, obj.Bullets(i).Position(2) + h / 2];
                        end
                    catch e
                        % Failed to update graphic, mark for removal
                        bulletsToRemove(i) = true;
                        continue;
                    end
                else
                    % Regular bullet update (unchanged)
                    try
                        obj.Bullets(i).Graphic.XData = obj.Bullets(i).Position(1);
                        obj.Bullets(i).Graphic.YData = obj.Bullets(i).Position(2);
                    catch
                        bulletsToRemove(i) = true;
                        continue;
                    end

                end
                if obj.Bullets(i).Position(1) < obj.AxesXLim(1) || ...
                        obj.Bullets(i).Position(1) > obj.AxesXLim(2) || ...
                        obj.Bullets(i).Position(2) < obj.AxesYLim(1) || ...
                        obj.Bullets(i).Position(2) > obj.AxesYLim(2)
                    bulletsToRemove(i) = true;
                end
            end

            obj.removeBullets(bulletsToRemove);
        end
        function updateEnemies(obj)
            % 若無敵人則跳過
            if isempty(obj.Enemies)
                return;
            end

            % 處理每個敵人
            for i = 1:length(obj.Enemies)
                % 確保敵人圖形有效
                if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
                    % 根據敵人類型重建圖形
                    if strcmp(obj.Enemies(i).Type, 'boss')
                        % 特殊處理BOSS圖形
                        obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                            'Position', [0, 0, 60, 60], ... % 更大尺寸
                            'FaceColor', [1, 0, 1], ... % 洋紅色
                            'Curvature', 0.3); % 圓角矩形
                    else
                        % 普通敵人圖形
                        obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                            'Position', [0, 0, 30, 30], ...
                            'FaceColor', 'r');
                    end
                    updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                end

                % 計算朝向玩家的方向向量
                directionToPlayer = obj.Player.Position - obj.Enemies(i).Position;
                distanceToPlayer = norm(directionToPlayer);
                % 標準化方向向量
                if distanceToPlayer > 0
                    normalizedDirection = directionToPlayer / distanceToPlayer;
                else
                    normalizedDirection = [0, 0];
                end

                if strcmp(obj.Enemies(i).Type, 'boss')
                    % BOSS專用邏輯
                    obj.Enemies(i).AttackCooldown = max(0, obj.Enemies(i).AttackCooldown-0.016);
                    obj.Enemies(i).SkillCooldown = max(0, obj.Enemies(i).SkillCooldown-0.016);

                    % 更新技能警示計時器
                    if obj.Enemies(i).SkillWarningTimer > 0
                        obj.Enemies(i).SkillWarningTimer = obj.Enemies(i).SkillWarningTimer - 0.016;

                        % 閃爍效果
                        if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                            % 創建閃爍效果
                            blinkInterval = 0.2; % 每0.2秒閃爍一次
                            blinkPhase = mod(obj.Enemies(i).SkillWarningTimer, blinkInterval);
                            if blinkPhase < blinkInterval / 2
                                obj.Enemies(i).SkillWarning.FaceAlpha = 0.5;
                            else
                                obj.Enemies(i).SkillWarning.FaceAlpha = 0.1;
                            end
                        end

                        % 警示結束，執行技能傷害
                        if obj.Enemies(i).SkillWarningTimer <= 0
                            % 移除警示圖形
                            if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                                warningCenter = [mean(obj.Enemies(i).SkillWarning.XData), ...
                                    mean(obj.Enemies(i).SkillWarning.YData)];
                                delete(obj.Enemies(i).SkillWarning);
                                obj.Enemies(i).SkillWarning = [];

                                % 執行技能傷害
                                obj.executeBossSkillDamage(i, warningCenter, 60);
                            end
                        end
                    end

                    % 普通攻擊（火球）
                    if obj.Enemies(i).AttackCooldown <= 0
                        obj.fireBullet(obj.Enemies(i).Position, normalizedDirection, true, obj.Enemies(i).Attack);
                        obj.Enemies(i).AttackCooldown = 0.5;
                    end

                    % 技能攻擊邏輯
                    if obj.Enemies(i).SkillCooldown <= 0 && obj.Enemies(i).SkillWarningTimer <= 0
                        % 隨機決定是否使用技能（30%機率）
                        % if rand() < 0.3
                        obj.useBossSkill(i);
                        % end
                    end
                else

                    % 處理敵人攻擊冷卻
                    if obj.Enemies(i).AttackCooldown > 0
                        obj.Enemies(i).AttackCooldown = obj.Enemies(i).AttackCooldown - 1;
                    end

                    % 檢查是否在攻擊範圍內且冷卻結束
                    if distanceToPlayer <= obj.Enemies(i).AttackRange && obj.Enemies(i).AttackCooldown <= 0
                        % 執行攻擊
                        obj.Player.Health = obj.Player.Health - obj.Enemies(i).Attack;

                        % 設置攻擊冷卻（120幀）
                        obj.Enemies(i).AttackCooldown = 120;

                        % 視覺效果 - 閃爍敵人顏色表示攻擊
                        originalColor = obj.Enemies(i).Graphic.FaceColor;
                        obj.Enemies(i).Graphic.FaceColor = [1, 1, 0]; % 黃色閃爍
                        pause(0.05);
                        obj.Enemies(i).Graphic.FaceColor = originalColor;

                        % 檢查玩家是否死亡
                        if obj.Player.Health <= 0
                            obj.showGameOverScreen();
                            return;
                        end
                    end

                    % 更新減速效果
                    if isfield(obj.Enemies(i), 'SlowTimer') && obj.Enemies(i).SlowTimer > 0
                        obj.Enemies(i).SlowTimer = obj.Enemies(i).SlowTimer - 0.016;
                        if obj.Enemies(i).SlowTimer <= 0
                            obj.Enemies(i).PoisonSlowed = false;
                        end
                    end

                    % 設定移動速度時考慮減速效果
                    switch obj.Enemies(i).Type
                        case 'melee'
                            moveSpeed = 2;
                        case 'ranged'
                            moveSpeed = 1;
                        otherwise
                            moveSpeed = 1.5;
                    end

                    % 如果被毒減速，速度減半
                    if isfield(obj.Enemies(i), 'PoisonSlowed') && obj.Enemies(i).PoisonSlowed
                        moveSpeed = moveSpeed * 0.5;
                    end


                    % 保存原始位置
                    originalPos = obj.Enemies(i).Position;

                    % 計算潛在的新位置
                    newPos = originalPos + normalizedDirection * moveSpeed;

                    % 檢查是否會與玩家碰撞
                    willCollideWithPlayer = obj.checkAABBCollision(newPos, 30, obj.Player.Position, obj.Player.Size);

                    % 檢查是否會與其他敵人碰撞
                    willCollideWithEnemy = false;
                    for j = 1:length(obj.Enemies)
                        if i ~= j && obj.checkAABBCollision(newPos, 30, obj.Enemies(j).Position, 30)
                            willCollideWithEnemy = true;
                            break;
                        end
                    end

                    % 只有在沒有碰撞時才移動
                    if ~willCollideWithPlayer && ~willCollideWithEnemy
                        obj.Enemies(i).Position = newPos;
                    end

                    % 更新敵人圖形位置
                    updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);

                end
            end
        end
        function checkBulletCollisions(obj)
            % 無子彈或敵人則跳過
            if isempty(obj.Bullets) || isempty(obj.Enemies)
                return;
            end

            % 標記要刪除的子彈
            bulletsToRemove = false(1, length(obj.Bullets));
            % 標記要刪除的敵人
            enemiesToRemove = false(1, length(obj.Enemies));

            % 檢查每顆子彈與每個敵人是否碰撞
            for b = 1:length(obj.Bullets)
                % 確保子彈圖形有效
                if ~isfield(obj.Bullets(b), 'Graphic') || ~isvalid(obj.Bullets(b).Graphic)
                    bulletsToRemove(b) = true;
                    continue;
                end
                if obj.Bullets(b).IsBossBullet
                    % Handle fireball collision with player
                    dist = norm(obj.Bullets(b).Position-obj.Player.Position);
                    collisionRadius = obj.Player.Size / 2;

                    % Determine collision size based on bullet type
                    if isfield(obj.Bullets(b), 'Size')
                        bulletSize = obj.Bullets(b).Size;
                    else
                        bulletSize = 15; % Default size for old-style boss bullets
                    end

                    if dist < (collisionRadius + bulletSize)
                        obj.Player.Health = obj.Player.Health - obj.Bullets(b).Damage;
                        bulletsToRemove(b) = true;
                    end
                else
                    for e = 1:length(obj.Enemies)
                        % 確保敵人圖形有效
                        if ~isfield(obj.Enemies(e), 'Graphic') || ~isvalid(obj.Enemies(e).Graphic)
                            continue;
                        end

                        dist = norm(obj.Bullets(b).Position-obj.Enemies(e).Position);

                        % 若距離小於敵人半徑，判定為碰撞
                        if dist < obj.Enemies(e).Graphic.Position(3) / 2

                            bulletsToRemove(b) = true;

                            obj.Enemies(e).Health = obj.Enemies(e).Health - obj.Player.Attack;

                            if obj.Enemies(e).Health <= 0
                                enemiesToRemove(e) = true;
                            end

                            break; % 一顆子彈只碰撞一次
                        end
                    end
                end
            end

            % 刪除碰撞的子彈
            obj.removeBullets(bulletsToRemove);

            % 刪除死亡的敵人
            obj.removeEnemies(enemiesToRemove);
        end

        function resolveEnemyCollisions(obj)
            % 若怪物數量小於2，則不需檢查碰撞
            if length(obj.Enemies) < 2
                return;
            end

            % 檢查每對怪物
            for i = 1:length(obj.Enemies) - 1
                for j = i + 1:length(obj.Enemies)
                    % 檢查碰撞
                    if obj.checkAABBCollision(obj.Enemies(i).Position, 30, ...
                            obj.Enemies(j).Position, 30)
                        % 計算從怪物j到怪物i的方向向量
                        direction = obj.Enemies(i).Position - obj.Enemies(j).Position;

                        % 標準化方向向量
                        if norm(direction) > 0
                            direction = direction / norm(direction);
                        else
                            % 如果在同一點，隨機推開
                            angle = rand() * 2 * pi;
                            direction = [cos(angle), sin(angle)];
                        end

                        % 增加分離距離
                        separation = 5.0; % 增加至5.0（原為2.0）

                        % 分離兩個敵人
                        obj.Enemies(i).Position = obj.Enemies(i).Position + direction * separation;
                        obj.Enemies(j).Position = obj.Enemies(j).Position - direction * separation;

                        % 更新圖形位置
                        updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                        updatePosition(obj.Enemies(j).Graphic, obj.Enemies(j).Position);
                    end
                end
            end
        end
        function checkPlayerEnemyCollision(obj)
            % 檢查玩家與敵人碰撞
            if isempty(obj.Enemies)
                return;
            end

            % 檢查每個敵人
            for i = 1:length(obj.Enemies)
                if obj.checkAABBCollision(obj.Player.Position, obj.Player.Size, ...
                        obj.Enemies(i).Position, 30)
                    % 計算從敵人到玩家的方向向量
                    direction = obj.Player.Position - obj.Enemies(i).Position;

                    % 標準化方向向量
                    if norm(direction) > 0
                        direction = direction / norm(direction);
                    else
                        direction = [0, 1]; % 預設方向
                    end

                    % 計算所需的最小分離距離
                    minDistance = (obj.Player.Size + 30) / 2 + 2; % 半尺寸和加上緩衝

                    % 計算目前距離
                    currentDistance = norm(obj.Player.Position-obj.Enemies(i).Position);

                    % 計算需要推開的距離
                    pushDistance = minDistance - currentDistance;

                    % 只有需要分離時才移動
                    if pushDistance > 0
                        obj.Player.Position = obj.Player.Position + direction * pushDistance;
                        updatePosition(obj.Player.Graphic, obj.Player.Position);
                    end

                    return; % 處理完一個碰撞後返回
                end
            end
        end
        function fireBullet(obj, startPos, direction, isBossBullet, attackerAttack)
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');
            if isBossBullet && ~isempty(obj.FireballFrames)
                % Calculate angle for rotation (in degrees, 0 = right)
                angle = atan2(direction(2), direction(1)) * 180 / pi;

                % Get the first frame
                frame = obj.FireballFrames{1};
                img = frame.Image;
                alpha = frame.Alpha;

                % Rotate the image to point in direction of travel
                rotatedImg = imrotate(img, -angle);
                if ~isempty(alpha)
                    rotatedAlpha = imrotate(alpha, -angle);
                else
                    rotatedAlpha = [];
                end

                % Calculate size and positioning
                [h, w, ~] = size(rotatedImg);

                % Create fireball image
                hold(obj.GameAxes, 'on');
                if ~isempty(rotatedAlpha)
                    h_img = image(obj.GameAxes, [startPos(1) - w / 2, startPos(1) + w / 2], ...
                        [startPos(2) - h / 2, startPos(2) + h / 2], ...
                        rotatedImg, 'AlphaData', rotatedAlpha);
                else
                    h_img = image(obj.GameAxes, [startPos(1) - w / 2, startPos(1) + w / 2], ...
                        [startPos(2) - h / 2, startPos(2) + h / 2], ...
                        rotatedImg);
                end
                hold(obj.GameAxes, 'off');

                % Create new bullet with all fields
                newBullet = struct( ...
                    'Position', startPos, ...
                    'Velocity', direction*3, ...
                    'Damage', attackerAttack, ...
                    'IsBossBullet', true, ...
                    'Graphic', h_img, ...
                    'AnimationFrame', 1, ...
                    'FrameCount', length(obj.FireballFrames), ...
                    'AnimationTimer', 0, ...
                    'AnimationSpeed', 0.075, ...
                    'Angle', angle, ...
                    'Size', 25);
            else
                % Regular bullet parameters
                markerSize = 8;
                color = [0, 0, 0]; % Black
                bulletSpeed = 15;

                % Create bullet graphic
                bulletGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o', ...
                    'MarkerSize', markerSize, ...
                    'MarkerFaceColor', color, ...
                    'MarkerEdgeColor', color);

                % Create regular bullet with all fields (default values for animation fields)
                newBullet = struct( ...
                    'Position', startPos, ...
                    'Velocity', direction*bulletSpeed, ...
                    'Damage', attackerAttack, ...
                    'IsBossBullet', isBossBullet, ...
                    'Graphic', bulletGraphic, ...
                    'AnimationFrame', 0, ... % Default value
                    'FrameCount', 1, ... % Default value
                    'AnimationTimer', 0, ... % Default value
                    'AnimationSpeed', 0, ... % Default value
                    'Angle', 0, ... % Default value
                    'Size', markerSize); % Use marker size
            end

            % Add to bullets array
            if isempty(obj.Bullets)
                obj.Bullets = newBullet;
            else
                obj.Bullets(end+1) = newBullet;
            end
            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function removeBullets(obj, indices)
            % 若沒有要刪除的子彈，直接返回
            if ~any(indices)
                return;
            end

            % 刪除圖形對象
            for i = find(indices)
                delete(obj.Bullets(i).Graphic);
            end

            % 從陣列中刪除
            obj.Bullets(indices) = [];
        end
        function removeEnemies(obj, indices)
            % 若沒有要刪除的敵人，直接返回
            if ~any(indices)
                return;
            end
            boss_dead = false;

            % 刪除圖形對象
            for i = find(indices)
                delete(obj.Enemies(i).Graphic);

                if strcmp(obj.Enemies(i).Type, 'boss')
                    boss_dead = true;
                    % 使用 isgraphics 並先檢查是否為空
                    if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                        delete(obj.Enemies(i).SkillWarning);
                    end
                end
            end

            obj.Enemies(indices) = [];

            if (boss_dead)
                obj.showVictoryScreen();
            end

        end
        function cleanupGameState(obj)
            % 重置遊戲狀態
            obj.isPaused = false;

            % 清理遊戲對象
            if ~isempty(obj.Bullets)
                for i = 1:length(obj.Bullets)
                    if isfield(obj.Bullets(i), 'Graphic') && isvalid(obj.Bullets(i).Graphic)
                        delete(obj.Bullets(i).Graphic);
                    end
                end
                obj.Bullets = struct('Position', {}, 'Velocity', {}, 'Damage', {}, 'IsBossBullet', {}, ...
                    'Graphic', {}, 'AnimationFrame', {}, 'FrameCount', {}, ...
                    'AnimationTimer', {}, 'AnimationSpeed', {}, 'Angle', {}, 'Size', {});

            end

            % 清理玩家資訊標籤
            try
                if ~isempty(obj.HealthLabel) && isvalid(obj.HealthLabel)
                    delete(obj.HealthLabel);
                end
            catch
                % 忽略錯誤
            end
            obj.HealthLabel = [];

            try
                if ~isempty(obj.AttackLabel) && isvalid(obj.AttackLabel)
                    delete(obj.AttackLabel);
                end
            catch
                % 忽略錯誤
            end
            obj.AttackLabel = [];

            % 清理計時器
            try
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                    delete(obj.GameTimer);
                end
            catch
            end
            obj.GameTimer = [];

            % 清理時間標籤
            try
                if ~isempty(obj.TimeLabel) && isvalid(obj.TimeLabel)
                    delete(obj.TimeLabel);
                end
            catch

            end
            obj.TimeLabel = [];

            % 清理敵人與玩家
            if ~isempty(obj.Enemies)
                for i = 1:length(obj.Enemies)
                    if isfield(obj.Enemies(i), 'Graphic') && isgraphics(obj.Enemies(i).Graphic)
                        delete(obj.Enemies(i).Graphic);
                    end
                    % 清理boss技能警示
                    if isfield(obj.Enemies(i), 'SkillWarning') && ...
                            ~isempty(obj.Enemies(i).SkillWarning) && ...
                            isgraphics(obj.Enemies(i).SkillWarning)
                        delete(obj.Enemies(i).SkillWarning);
                    end
                end
            end
            obj.Enemies = [];

            if isfield(obj, 'Player') && ~isempty(obj.Player) && isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                delete(obj.Player.Graphic);
            end
            obj.Player = [];
            obj.BossAdded = false;

            % 清理技能UI標籤
            try
                if ~isempty(obj.SkillLabel) && isvalid(obj.SkillLabel)
                    delete(obj.SkillLabel);
                end
            catch
            end
            obj.SkillLabel = [];

            % 清理技能說明標籤
            try
                if ~isempty(obj.SkillDescLabel) && isvalid(obj.SkillDescLabel)
                    delete(obj.SkillDescLabel);
                end
            catch
            end
            obj.SkillDescLabel = [];

            % 清理技能圖標
            try
                if ~isempty(obj.SkillIcon) && isvalid(obj.SkillIcon)
                    delete(obj.SkillIcon);
                end
            catch
            end
            obj.SkillIcon = [];

            % 清理技能動畫效果
            for i = 1:length(obj.SkillEffects)
                if ~isempty(obj.SkillEffects{i}) && ...
                        isfield(obj.SkillEffects{i}, 'Graphic') && ...
                        ~isempty(obj.SkillEffects{i}.Graphic) && ...
                        isvalid(obj.SkillEffects{i}.Graphic)
                    delete(obj.SkillEffects{i}.Graphic);
                end
            end
            obj.SkillEffects = {};

            % 重置技能冷卻
            obj.SkillCooldown = 0;

            % 清理第二個技能UI
            try
                if ~isempty(obj.Skill2Label) && isvalid(obj.Skill2Label)
                    delete(obj.Skill2Label);
                end
            catch
            end
            obj.Skill2Label = [];

            try
                if ~isempty(obj.Skill2DescLabel) && isvalid(obj.Skill2DescLabel)
                    delete(obj.Skill2DescLabel);
                end
            catch
            end
            obj.Skill2DescLabel = [];

            try
                if ~isempty(obj.Skill2Icon) && isvalid(obj.Skill2Icon)
                    delete(obj.Skill2Icon);
                end
            catch
            end
            obj.Skill2Icon = [];

            % 清理毒藥水投擲物
            for i = 1:length(obj.PoisonProjectiles)
                if ~isempty(obj.PoisonProjectiles{i}) && ...
                        isfield(obj.PoisonProjectiles{i}, 'Graphic') && ...
                        isvalid(obj.PoisonProjectiles{i}.Graphic)
                    delete(obj.PoisonProjectiles{i}.Graphic);
                end
            end
            obj.PoisonProjectiles = {};

            % 清理毒區域
            for i = 1:length(obj.PoisonAreas)
                if ~isempty(obj.PoisonAreas{i}) && ...
                        isfield(obj.PoisonAreas{i}, 'Graphic') && ...
                        isvalid(obj.PoisonAreas{i}.Graphic)
                    delete(obj.PoisonAreas{i}.Graphic);
                end
            end
            obj.PoisonAreas = {};

            % 重置第二個技能冷卻
            obj.Skill2Cooldown = 0;

            % 清理第三個技能UI
            try
                if ~isempty(obj.Skill3Label) && isvalid(obj.Skill3Label)
                    delete(obj.Skill3Label);
                end
            catch
            end
            obj.Skill3Label = [];

            try
                if ~isempty(obj.Skill3DescLabel) && isvalid(obj.Skill3DescLabel)
                    delete(obj.Skill3DescLabel);
                end
            catch
            end
            obj.Skill3DescLabel = [];

            try
                if ~isempty(obj.Skill3Icon) && isvalid(obj.Skill3Icon)
                    delete(obj.Skill3Icon);
                end
            catch
            end
            obj.Skill3Icon = [];

            % 清理動畫
            % 技能1
            for i = 1:length(obj.Skill1Animations)
                if ~isempty(obj.Skill1Animations{i}) && ...
                        isfield(obj.Skill1Animations{i}, 'Graphic') && ...
                        ~isempty(obj.Skill1Animations{i}.Graphic) && ...
                        isgraphics(obj.Skill1Animations{i}.Graphic)
                    delete(obj.Skill1Animations{i}.Graphic);
                end
            end
            obj.Skill1Animations = {};

            % 技能3
            if ~isempty(obj.Skill3Animation) && isfield(obj.Skill3Animation, 'Graphic') && ...
                    ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                delete(obj.Skill3Animation.Graphic);
            end
            obj.Skill3Animation = [];

            % 重置第三個技能冷卻
            obj.Skill3Cooldown = 0;

            obj.EnemySpawnTimer = 0;

        end

        function showVictoryScreen(obj)
            % 停止遊戲循環
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
            end
            if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                stop(obj.GameTimer);
            end

            % 隱藏其他面板
            obj.CurrentPanel.Visible = 'off';

            % 顯示勝利畫面
            obj.VictoryPanel.Visible = 'on';
            obj.CurrentPanel = obj.VictoryPanel;

            % 強制更新畫面
            drawnow;
        end
        function BossWarning(obj, state)
            switch state
                case 'start'

                    % 計算BOSS生成位置
                    bossPos = [obj.gameWidth / 2, obj.gameHeight - 100];

                    % 創建半透明紅色標記
                    obj.BossWarningGraphic = rectangle(obj.GameAxes, ...
                        'Position', [bossPos(1) - 50, bossPos(2) - 50, 100, 100], ...
                        'FaceColor', [1, 0, 0], ...
                        'FaceAlpha', 0.3, ...
                        'EdgeColor', 'none', ...
                        'Curvature', 0.3);

                    % 啟動閃爍效果
                    obj.startBlink();
                    % end

                case 'end'

                    % 移除閃爍計時器
                    if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
                        stop(obj.BlinkTimer);
                        delete(obj.BlinkTimer);
                        obj.BlinkTimer = [];
                    end

                    % 移除預警圖形
                    if isvalid(obj.BossWarningGraphic)
                        delete(obj.BossWarningGraphic);
                        obj.BossWarningGraphic = [];
                    end
            end
        end
        function updateTimer(obj)
            THESHOWTIME = 10;

            % 更新計時
            obj.ElapsedTime = obj.ElapsedTime + 1;
            minutes = floor(obj.ElapsedTime/60);
            seconds = mod(obj.ElapsedTime, 60);

            % 格式化顯示
            obj.TimeStr = sprintf('%02d:%02d', minutes, seconds);

            % 更新UI（確保在主線程執行）
            if isvalid(obj.TimeLabel)
                obj.TimeLabel.Text = ['時間: ', obj.TimeStr];
            end
            if (obj.ElapsedTime == THESHOWTIME - 3) && ~obj.BossAdded
                obj.BossWarning('start');
            end

            if ~obj.BossAdded && obj.ElapsedTime >= THESHOWTIME && strcmp(obj.GameState, 'PLAYING')
                obj.BossWarning('end');
                obj.initBOSS()
            end
        end

        function loadPlayerAnimations(obj)
            % 加載靜止(idle)動畫
            idlePath = fullfile(obj.basePath, 'images', 'body', 'idle.png');
            runPath = fullfile(obj.basePath, 'images', 'body', 'run.png');

            try
                [idleSheet, ~, idleAlpha] = imread(idlePath);
                [runSheet, ~, runAlpha] = imread(runPath);

                % 設定幀數和方向數
                numDirections = 4; % 上、左、下、右

                % 正確分割 idle 表 (第2列的圖片)
                idleFrameHeight = floor(size(idleSheet, 1)/4); % 確保整數
                idleFrameWidth = floor(size(idleSheet, 2)/2); % 確保整數

                % idle取第2列
                idleCol = 2;
                obj.IdleFrames = cell(numDirections, 1);

                % 分配4個方向的靜態幀 (上、左、下、右)
                for dir = 1:numDirections
                    % 計算當前方向幀的位置 (第2列的位置)
                    startY = floor((dir - 1)*idleFrameHeight) + 1;
                    startX = floor((idleCol - 1)*idleFrameWidth) + 1;
                    endY = floor(startY+idleFrameHeight-1);
                    endX = floor(startX + idleFrameWidth - 1);

                    % 範圍安全檢查
                    endY = min(endY, size(idleSheet, 1));
                    endX = min(endX, size(idleSheet, 2));

                    % 提取單一幀
                    frame = idleSheet(startY:endY, startX:endX, :);
                    alpha = idleAlpha(startY:endY, startX:endX);

                    frame = flipud(frame);
                    alpha = flipud(alpha);

                    obj.IdleFrames{dir} = struct('Image', frame, 'Alpha', alpha);
                end

                % 處理運行動畫 - 每個方向有8幀
                runFrameHeight = floor(size(runSheet, 1)/4); % 確保整數
                runFrameWidth = floor(size(runSheet, 2)/8); % 確保整數

                obj.RunFrames = cell(numDirections, 8); % 4個方向，每個方向8幀

                % 分配每個方向的運行幀
                for dir = 1:numDirections
                    for frame = 1:8
                        % 計算當前幀的位置
                        startY = floor((dir - 1)*runFrameHeight) + 1;
                        startX = floor((frame - 1)*runFrameWidth) + 1;
                        endY = floor(startY+runFrameHeight-1);
                        endX = floor(startX + runFrameWidth - 1);

                        % 範圍安全檢查
                        endY = min(endY, size(runSheet, 1));
                        endX = min(endX, size(runSheet, 2));

                        % 提取幀和Alpha通道
                        frameImg = runSheet(startY:endY, startX:endX, :);
                        frameAlpha = runAlpha(startY:endY, startX:endX);

                        frameImg = flipud(frameImg);
                        frameAlpha = flipud(frameAlpha);

                        obj.RunFrames{dir, frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                    end
                end

                % 設置初始狀態
                obj.CurrentDirection = 3; % 預設向下
                obj.IsMoving = false;
                obj.CurrentFrame = 1;
                obj.AnimationTimer = 0;
                obj.AnimationSpeed = 0.1; % 動畫速度

            catch ME
                warning(ME.identifier, '載入動畫失敗：%s', ME.message);
                obj.IdleFrames = {};
                obj.RunFrames = {};
            end
        end


        function handleKeyRelease(obj, event)
            % 遊戲進行中才處理按鍵釋放
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                % 更新按鍵狀態
                if ismember(event.Key, {'w', 'a', 's', 'd'})
                    obj.KeysPressed.(event.Key) = false;

                    % 檢查是否還有其他方向鍵被按下
                    if ~any(structfun(@(x) x, obj.KeysPressed))
                        obj.IsMoving = false;
                    else
                        % 更新移動方向為最後一個還在按下的方向鍵
                        if obj.KeysPressed.w
                            obj.CurrentDirection = 1; % 上
                        elseif obj.KeysPressed.a
                            obj.CurrentDirection = 2; % 左
                        elseif obj.KeysPressed.s
                            obj.CurrentDirection = 3; % 下
                        elseif obj.KeysPressed.d
                            obj.CurrentDirection = 4; % 右
                        end
                    end
                end
            end
        end

        function useSkill(obj)
            % 檢查技能是否可用
            if obj.SkillCooldown > 0
                return; % 技能在冷卻中
            end
            obj.SkillIcon.Visible = 'off';
            % 使用技能
            skillDamage = obj.Player.Attack * 1.5;
            skillRadius = 60; % 技能範圍半徑

            % 在鼠標位置創建範圍傷害
            obj.createAreaDamage(obj.MousePos, skillRadius, skillDamage);

            % 創建動畫效果
            obj.createSkillAnimation(obj.MousePos, skillRadius);

            % 設置冷卻時間
            obj.SkillCooldown = obj.SkillMaxCooldown;
            obj.SkillLabel.Visible = 'on';
        end

        function createAreaDamage(obj, center, radius, damage)
            % 檢查範圍內的敵人
            if isempty(obj.Enemies)
                return;
            end

            enemiesToRemove = false(1, length(obj.Enemies));

            for i = 1:length(obj.Enemies)
                % 計算敵人與技能中心的距離
                distance = norm(obj.Enemies(i).Position-center);

                % 如果在範圍內，造成傷害
                if distance <= radius
                    obj.Enemies(i).Health = obj.Enemies(i).Health - damage;

                    % 標記死亡的敵人
                    if obj.Enemies(i).Health <= 0
                        enemiesToRemove(i) = true;
                    end

                    % 視覺效果 - 敵人受傷閃爍
                    if isvalid(obj.Enemies(i).Graphic)
                        originalColor = obj.Enemies(i).Graphic.FaceColor;
                        obj.Enemies(i).Graphic.FaceColor = [1, 1, 0]; % 黃色閃爍
                        pause(0.05);
                        obj.Enemies(i).Graphic.FaceColor = originalColor;
                    end
                end
            end

            % 移除死亡的敵人
            obj.removeEnemies(enemiesToRemove);
        end

        function createSkillAnimation(obj, center, radius)
            % 創建技能1動畫效果
            if isempty(obj.Skill1Frames)
                % 如果沒有載入動畫幀，使用原有的圓形效果
                wasHeld = ishold(obj.GameAxes);
                hold(obj.GameAxes, 'on');

                theta = linspace(0, 2*pi, 50);
                x = center(1) + radius * cos(theta);
                y = center(2) + radius * sin(theta);

                skillEffect = fill(obj.GameAxes, x, y, [1, 1, 0], ...
                    'FaceAlpha', 0.6, ...
                    'EdgeColor', [1, 0.8, 0], ...
                    'LineWidth', 3);

                obj.SkillEffects{end+1} = struct('Graphic', skillEffect, 'Timer', 0.5);

                if ~wasHeld
                    hold(obj.GameAxes, 'off');
                end
                return;
            end

            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 使用第一幀創建初始圖像
            firstFrame = obj.Skill1Frames{1};
            [h, w, ~] = size(firstFrame.Image);

            % 計算動畫大小（根據技能範圍調整）
            animationSize = radius * 2; % 動畫大小基於技能範圍
            scaleFactor = animationSize / max(h, w);

            % 創建動畫實例
            newAnimation = struct( ...
                'Position', center, ...
                'FrameIndex', 1, ...
                'FrameTimer', 0, ...
                'FrameInterval', 0.1, ... % 每幀持續0.1秒
                'ScaleFactor', scaleFactor, ...
                'Graphic', [], ...
                'IsActive', true, ...
                'TotalTimer', 0, ...
                'MaxDuration', 0.9 ... % 9幀 × 0.1秒 = 0.9秒
                );

            % 創建第一幀的圖像、接收返回值
            newAnimation = obj.updateSkill1Frame(newAnimation);

            % 添加到動畫列表
            obj.Skill1Animations{end+1} = newAnimation;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        % function with return value
        function animation = updateSkill1Frame(obj, animation)
            % 更新技能1動畫幀 - 返回修改後的動畫結構體
            if ~animation.IsActive || animation.FrameIndex > length(obj.Skill1Frames)
                return;
            end

            % 獲取當前幀
            frame = obj.Skill1Frames{animation.FrameIndex};
            img = frame.Image;
            alpha = frame.Alpha;

            % 計算圖像大小和位置
            [h, w, ~] = size(img);
            scaledW = w * animation.ScaleFactor;
            scaledH = h * animation.ScaleFactor;

            centerPos = animation.Position;

            % 修改位置計算 - 讓動畫底部對應到目標位置
            xData = [centerPos(1) - scaledW / 2, centerPos(1) + scaledW / 2]; % 水平居中
            yData = [centerPos(2), centerPos(2) + scaledH]; % 底部對應到目標位置

            % 如果已有圖像，先刪除
            if ~isempty(animation.Graphic) && isgraphics(animation.Graphic)
                delete(animation.Graphic);
            end

            % 創建新的圖像
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            animation.Graphic = image(obj.GameAxes, xData, yData, img, ...
                'AlphaData', alpha);

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end

            % 返回修改後的動畫結構體
        end


        function updateSkillSystem(obj, deltaTime)
            % 更新技能冷卻
            if obj.SkillCooldown > 0
                obj.SkillCooldown = max(0, obj.SkillCooldown-deltaTime);
            end

            if obj.Skill2Cooldown > 0
                obj.Skill2Cooldown = max(0, obj.Skill2Cooldown-deltaTime);
            end

            % 更新第三個技能冷卻
            if obj.Skill3Cooldown > 0
                obj.Skill3Cooldown = max(0, obj.Skill3Cooldown-deltaTime);
            end
            % 更新技能1動畫
            obj.updateSkill1Animations(deltaTime);

            % 更新原有的技能動畫效果（備用）
            effectsToRemove = [];
            for i = 1:length(obj.SkillEffects)
                obj.SkillEffects{i}.Timer = obj.SkillEffects{i}.Timer - deltaTime;

                if obj.SkillEffects{i}.Timer <= 0
                    % 動畫結束，移除效果
                    if ~isempty(obj.SkillEffects{i}.Graphic) && isgraphics(obj.SkillEffects{i}.Graphic)
                        delete(obj.SkillEffects{i}.Graphic);
                    end
                    effectsToRemove(end+1) = i;
                else
                    % 更新透明度（淡出效果）
                    if ~isempty(obj.SkillEffects{i}.Graphic) && isgraphics(obj.SkillEffects{i}.Graphic)
                        alpha = obj.SkillEffects{i}.Timer / 0.5; % 原始持續時間
                        obj.SkillEffects{i}.Graphic.FaceAlpha = alpha * 0.6;
                    end
                end
            end

            % 移除已結束的動畫效果
            obj.SkillEffects(effectsToRemove) = [];
        end

        function updateSkill1Animations(obj, deltaTime)
            % 更新技能1動畫列表
            animationsToRemove = [];

            for i = 1:length(obj.Skill1Animations)
                animation = obj.Skill1Animations{i};

                if ~animation.IsActive
                    animationsToRemove(end+1) = i;
                    continue;
                end

                % 更新總計時器
                animation.TotalTimer = animation.TotalTimer + deltaTime;
                animation.FrameTimer = animation.FrameTimer + deltaTime;

                % 檢查是否需要切換到下一幀
                if animation.FrameTimer >= animation.FrameInterval
                    animation.FrameTimer = 0;
                    animation.FrameIndex = animation.FrameIndex + 1;

                    % 檢查動畫是否結束
                    if animation.FrameIndex > length(obj.Skill1Frames) || ...
                            animation.TotalTimer >= animation.MaxDuration
                        % 動畫結束，清理
                        if ~isempty(animation.Graphic) && isgraphics(animation.Graphic)
                            delete(animation.Graphic);
                        end
                        animation.IsActive = false;
                        animationsToRemove(end+1) = i;
                    else
                        % 更新到下一幀
                        animation = obj.updateSkill1Frame(animation);
                    end
                end

                % 確保修改後的結構被保存
                obj.Skill1Animations{i} = animation;
            end

            % 移除已結束的動畫
            obj.Skill1Animations(animationsToRemove) = [];
        end


        function updateSkillUI(obj)
            if isvalid(obj.SkillLabel)
                if obj.SkillCooldown > 0
                    % 冷卻中 - 顯示剩餘時間，灰暗色，隱藏圖片
                    obj.SkillLabel.Text = sprintf('%.1f', obj.SkillCooldown);
                    obj.SkillLabel.FontColor = [0.5, 0.5, 0.5]; % 灰色
                    obj.SkillLabel.BackgroundColor = [0.3, 0.3, 0.3]; % 灰暗背景

                    % 隱藏技能圖標
                    if isvalid(obj.SkillIcon)
                        obj.SkillIcon.Visible = 'off';
                    end
                else
                    % 可用 - 不顯示數字，顯示圖片
                    obj.SkillLabel.Text = '';
                    obj.SkillLabel.BackgroundColor = [0.1, 0.1, 0.4]; % 正常背景
                    obj.SkillLabel.Visible = 'off';
                    % 顯示技能圖標
                    if isvalid(obj.SkillIcon)
                        obj.SkillIcon.Visible = 'on';
                    end
                end
            end
        end

        function useBossSkill(obj, bossIndex)
            % boss使用技能
            if obj.Enemies(bossIndex).SkillCooldown > 0
                return; % 技能在冷卻中
            end

            % 目標位置：玩家當前位置
            targetPos = obj.Player.Position;
            skillRadius = 60; % 技能範圍半徑

            % 開始警示效果
            obj.createBossSkillWarning(bossIndex, targetPos, skillRadius);

            % 設置冷卻時間
            obj.Enemies(bossIndex).SkillCooldown = obj.Enemies(bossIndex).SkillMaxCooldown;
        end

        function createBossSkillWarning(obj, bossIndex, center, radius)
            % 創建紅色警示效果
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 創建紅色圓形警示指示器
            theta = linspace(0, 2*pi, 50);
            x = center(1) + radius * cos(theta);
            y = center(2) + radius * sin(theta);

            % 創建填充圓形警示
            warningEffect = fill(obj.GameAxes, x, y, [1, 0, 0], ... % 紅色
                'FaceAlpha', 0.3, ...
                'EdgeColor', [1, 0, 0], ...
                'LineWidth', 2);

            % 存儲警示效果到boss
            obj.Enemies(bossIndex).SkillWarning = warningEffect;
            obj.Enemies(bossIndex).SkillWarningTimer = 1.0; % 警示持續1秒

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function executeBossSkillDamage(obj, bossIndex, center, radius)
            % 執行boss技能傷害
            skillDamage = obj.Enemies(bossIndex).Attack * 1.5;

            % 檢查玩家是否在範圍內
            distance = norm(obj.Player.Position-center);
            if distance <= radius
                obj.Player.Health = obj.Player.Health - skillDamage;

                % 視覺效果 - 玩家受傷閃爍
                if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                    % 創建受傷閃爍效果
                    if ~isempty(obj.IdleFrames)
                        % 如果使用圖像動畫，暫時改變透明度
                        originalAlpha = obj.Player.Graphic.AlphaData;
                        obj.Player.Graphic.AlphaData = originalAlpha * 0.5; % 半透明
                        pause(0.1);
                        obj.Player.Graphic.AlphaData = originalAlpha;
                    end
                end

                fprintf('玩家受到Boss技能攻擊，傷害：%.1f\n', skillDamage);
            end

            % 創建技能傷害動畫效果
            obj.createSkillAnimation(center, radius);

        end

        function useSkill2(obj)
            % 檢查技能是否可用
            if obj.Skill2Cooldown > 0
                return; % 技能在冷卻中
            end

            obj.Skill2Icon.Visible = 'off';

            % 投擲毒藥水到鼠標位置
            obj.throwPoisonBottle(obj.Player.Position, obj.MousePos);

            % 設置冷卻時間
            obj.Skill2Cooldown = obj.Skill2MaxCooldown;
            obj.Skill2Label.Visible = 'on';
        end

        function throwPoisonBottle(obj, startPos, targetPos)
            % 計算投擲方向和距離
            direction = targetPos - startPos;
            distance = norm(direction);

            if distance == 0
                return;
            end

            normalizedDirection = direction / distance;

            % 創建毒藥水投擲物
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 創建投擲物圖形（綠色圓點）
            projectileGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o', ...
                'MarkerSize', 12, ...
                'MarkerFaceColor', [0, 0.8, 0], ...
                'MarkerEdgeColor', [0, 0.6, 0], ...
                'LineWidth', 2);

            % 創建投擲物數據
            newProjectile = struct( ...
                'Position', startPos, ...
                'TargetPos', targetPos, ...
                'Speed', 8, ...
                'Graphic', projectileGraphic, ...
                'Direction', normalizedDirection ...
                );

            % 添加到投擲物陣列
            obj.PoisonProjectiles{end+1} = newProjectile;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function createPoisonArea(obj, center)
            % 創建毒區域效果
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            radius = 80; % 毒區域半徑

            % 創建綠色圓形毒區域
            theta = linspace(0, 2*pi, 50);
            x = center(1) + radius * cos(theta);
            y = center(2) + radius * sin(theta);

            % 創建填充圓形
            poisonArea = fill(obj.GameAxes, x, y, [0, 0.8, 0], ... % 綠色
                'FaceAlpha', 0.4, ...
                'EdgeColor', [0, 0.6, 0], ...
                'LineWidth', 2);

            % 創建毒區域數據
            newPoisonArea = struct( ...
                'Position', center, ...
                'Radius', radius, ...
                'Graphic', poisonArea, ...
                'Timer', 3.0, ... % 持續3秒
                'DamageTimer', 0, ... % 傷害計時器
                'DamageInterval', 1.0 ... % 每秒造成傷害
                );

            % 添加到毒區域陣列
            obj.PoisonAreas{end+1} = newPoisonArea;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function updatePoisonProjectiles(obj, deltaTime)
            % 更新毒藥水投擲物
            projectilesToRemove = [];

            for i = 1:length(obj.PoisonProjectiles)
                projectile = obj.PoisonProjectiles{i};

                % 移動投擲物
                projectile.Position = projectile.Position + projectile.Direction * projectile.Speed;

                % 更新圖形位置
                if isvalid(projectile.Graphic)
                    projectile.Graphic.XData = projectile.Position(1);
                    projectile.Graphic.YData = projectile.Position(2);
                end

                % 檢查是否到達目標位置
                distance = norm(projectile.Position-projectile.TargetPos);
                if distance <= 10 % 到達目標位置
                    % 創建毒區域
                    obj.createPoisonArea(projectile.TargetPos);

                    % 移除投擲物
                    if isvalid(projectile.Graphic)
                        delete(projectile.Graphic);
                    end
                    projectilesToRemove(end+1) = i;
                end

                % 更新投擲物數據
                obj.PoisonProjectiles{i} = projectile;
            end

            % 移除已到達的投擲物
            obj.PoisonProjectiles(projectilesToRemove) = [];
        end

        function updatePoisonAreas(obj, deltaTime)
            % 更新毒區域
            areasToRemove = [];

            for i = 1:length(obj.PoisonAreas)
                area = obj.PoisonAreas{i};

                % 更新計時器
                area.Timer = area.Timer - deltaTime;
                area.DamageTimer = area.DamageTimer + deltaTime;

                % 檢查是否需要造成傷害
                if area.DamageTimer >= area.DamageInterval
                    obj.applyPoisonDamage(area);
                    area.DamageTimer = 0;
                end

                % 檢查是否過期
                if area.Timer <= 0
                    % 移除毒區域
                    if isvalid(area.Graphic)
                        delete(area.Graphic);
                    end
                    areasToRemove(end+1) = i;
                else
                    % 更新透明度（漸漸消失效果）
                    if isvalid(area.Graphic)
                        alpha = area.Timer / 3.0; % 原始持續時間
                        area.Graphic.FaceAlpha = alpha * 0.4;
                    end
                end

                % 更新區域數據
                obj.PoisonAreas{i} = area;
            end

            % 移除過期的區域
            obj.PoisonAreas(areasToRemove) = [];
        end

        function applyPoisonDamage(obj, area)
            % 對毒區域內的敵人造成傷害並減速
            if isempty(obj.Enemies)
                return;
            end

            skillDamage = obj.Player.Attack * 1.5;
            enemiesToRemove = false(1, length(obj.Enemies));

            for i = 1:length(obj.Enemies)
                % 計算敵人與毒區域中心的距離
                distance = norm(obj.Enemies(i).Position-area.Position);

                % 如果在毒區域內
                if distance <= area.Radius
                    % 造成傷害
                    obj.Enemies(i).Health = obj.Enemies(i).Health - skillDamage;

                    % 添加減速效果標記
                    obj.Enemies(i).PoisonSlowed = true;
                    obj.Enemies(i).SlowTimer = 1.2; % 減速效果持續1.2秒

                    % 檢查敵人是否死亡 分
                    if obj.Enemies(i).Health <= 0
                        enemiesToRemove(i) = true; % 標記移除
                    end

                    % 視覺效果
                    if isvalid(obj.Enemies(i).Graphic)
                        originalColor = obj.Enemies(i).Graphic.FaceColor;
                        obj.Enemies(i).Graphic.FaceColor = [0, 1, 0]; % 綠色閃爍
                        pause(0.05);
                        obj.Enemies(i).Graphic.FaceColor = originalColor;
                    end
                end
            end

            % 在循環結束後一次性移除所有死亡的敵人
            if any(enemiesToRemove)
                obj.removeEnemies(enemiesToRemove);
            end
        end


        function updateSkill2UI(obj)
            if isvalid(obj.Skill2Label)
                if obj.Skill2Cooldown > 0
                    % 冷卻中 - 顯示剩餘時間，灰暗色，隱藏圖片
                    obj.Skill2Label.Text = sprintf('%.1f', obj.Skill2Cooldown);
                    obj.Skill2Label.FontColor = [0.5, 0.5, 0.5];
                    obj.Skill2Label.BackgroundColor = [0.3, 0.3, 0.3];

                    if isvalid(obj.Skill2Icon)
                        obj.Skill2Icon.Visible = 'off';
                    end
                else
                    % 可用 - 不顯示數字，顯示圖片
                    obj.Skill2Label.Text = '';
                    obj.Skill2Label.BackgroundColor = [0.1, 0.1, 0.4];
                    obj.Skill2Label.Visible = 'off';

                    if isvalid(obj.Skill2Icon)
                        obj.Skill2Icon.Visible = 'on';
                    end
                end
            end
        end

        function loadExplosionFrames(obj)
            % 載入Effect.png並切割成爆炸動畫幀
            try
                effectPath = fullfile(obj.basePath, 'images', 'skill', 'Effect.png');
                [effectSheet, ~, effectAlpha] = imread(effectPath);

                numColumns = 9;
                numRows = 30;
                targetRow = 4;
                numFrames = 6;

                frameWidth = floor(size(effectSheet, 2)/numColumns);
                frameHeight = floor(size(effectSheet, 1)/numRows);

                obj.ExplosionFrames = cell(1, numFrames);

                for frame = 1:numFrames
                    % 計算第四row第frame張的位置
                    startY = floor((targetRow - 1)*frameHeight) + 1;
                    startX = floor((frame - 1)*frameWidth) + 1;
                    endY = min(startY+frameHeight-1, size(effectSheet, 1));
                    endX = min(startX + frameWidth - 1, size(effectSheet, 2));

                    % 提取幀
                    frameImg = effectSheet(startY:endY, startX:endX, :);

                    % 處理alpha通道
                    if ~isempty(effectAlpha)
                        frameAlpha = effectAlpha(startY:endY, startX:endX);
                    else
                        frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                    end
                    frameImg = flipud(frameImg);
                    frameAlpha = flipud(frameAlpha);
                    obj.ExplosionFrames{frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                end

            catch ME
                warning(ME.identifier, '載入爆炸動畫失敗：%s', ME.message);
                % 創建備用的爆炸效果
                obj.ExplosionFrames = {};
                for i = 1:6
                    % 創建漸變的橙紅色圓形作為備用
                    img = ones(100, 100, 3, 'uint8');
                    intensity = (7 - i) / 6; % 逐漸減弱
                    img(:, :, 1) = uint8(255*intensity); % Red
                    img(:, :, 2) = uint8(165*intensity); % Orange
                    img(:, :, 3) = uint8(0); % Blue
                    alpha = ones(100, 100) * intensity;
                    obj.ExplosionFrames{i} = struct('Image', img, 'Alpha', alpha);
                end
            end
        end

        function useSkill3(obj)
            % 檢查技能是否可用
            if obj.Skill3Cooldown > 0
                return; % 技能在冷卻中
            end

            obj.Skill3Icon.Visible = 'off';

            % 在畫面中央創建超級大爆炸
            centerPos = [obj.gameWidth / 2, obj.gameHeight / 2];
            obj.createSuperExplosion(centerPos);

            % 立即清除所有敵人
            obj.destroyAllEnemies();

            % 設置冷卻時間
            obj.Skill3Cooldown = obj.Skill3MaxCooldown;
            obj.Skill3Label.Visible = 'on';
        end

        function createSuperExplosion(obj, center)
            % 創建超級大爆炸動畫
            if isempty(obj.ExplosionFrames)
                % 如果沒有載入動畫幀，創建備用效果
                fprintf('警告：爆炸動畫載入失敗，使用備用效果\n');
                return;
            end

            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 使用第一幀創建初始圖像
            firstFrame = obj.ExplosionFrames{1};
            [h, w, ~] = size(firstFrame.Image);

            % 創建爆炸圖像（放大到畫面大小）
            explosionSize = min(obj.gameWidth, obj.gameHeight) * 0.8; % 占畫面80%
            scaleFactor = explosionSize / max(h, w);

            obj.Skill3Animation = struct( ...
                'Position', center, ...
                'FrameIndex', 1, ...
                'FrameTimer', 0, ...
                'FrameInterval', 0.15, ... % 每幀持續0.15秒
                'ScaleFactor', scaleFactor, ...
                'Graphic', [], ...
                'IsActive', true ...
                );

            % 創建第一幀的圖像
            obj.updateExplosionFrame();

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end


        function updateExplosionFrame(obj)
            % 更新爆炸動畫幀
            if isempty(obj.Skill3Animation) || ~obj.Skill3Animation.IsActive
                return;
            end

            frameIndex = obj.Skill3Animation.FrameIndex;
            if frameIndex > length(obj.ExplosionFrames)
                return;
            end

            % 獲取當前幀
            frame = obj.ExplosionFrames{frameIndex};
            img = frame.Image;
            alpha = frame.Alpha;

            % 計算圖像大小和位置
            [h, w, ~] = size(img);
            scaledW = w * obj.Skill3Animation.ScaleFactor;
            scaledH = h * obj.Skill3Animation.ScaleFactor;

            centerPos = obj.Skill3Animation.Position;
            xData = [centerPos(1) - scaledW / 2, centerPos(1) + scaledW / 2];
            yData = [centerPos(2) - scaledH / 2, centerPos(2) + scaledH / 2];

            % 如果已有圖像，先刪除
            if ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                delete(obj.Skill3Animation.Graphic);
            end

            % 創建新的圖像
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            obj.Skill3Animation.Graphic = image(obj.GameAxes, xData, yData, img, ...
                'AlphaData', alpha);

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function updateSkill3Animation(obj, deltaTime)
            % 更新超級大爆炸動畫
            if isempty(obj.Skill3Animation) || ~obj.Skill3Animation.IsActive
                return;
            end

            % 更新動畫計時器
            obj.Skill3Animation.FrameTimer = obj.Skill3Animation.FrameTimer + deltaTime;

            % 檢查是否需要切換到下一幀
            if obj.Skill3Animation.FrameTimer >= obj.Skill3Animation.FrameInterval
                obj.Skill3Animation.FrameTimer = 0;
                obj.Skill3Animation.FrameIndex = obj.Skill3Animation.FrameIndex + 1;

                % 檢查動畫是否結束
                if obj.Skill3Animation.FrameIndex > length(obj.ExplosionFrames)
                    % 動畫結束，清理動畫
                    if ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                        delete(obj.Skill3Animation.Graphic);
                    end
                    obj.Skill3Animation = [];

                else
                    % 更新到下一幀
                    obj.updateExplosionFrame();
                end
            end
        end


        function updateSkill3UI(obj)
            if isvalid(obj.Skill3Label)
                if obj.Skill3Cooldown > 0
                    % 冷卻中 - 顯示剩餘時間，灰暗色，隱藏圖片
                    obj.Skill3Label.Text = sprintf('%.1f', obj.Skill3Cooldown);
                    obj.Skill3Label.FontColor = [0.5, 0.5, 0.5];
                    obj.Skill3Label.BackgroundColor = [0.3, 0.3, 0.3];

                    if isvalid(obj.Skill3Icon)
                        obj.Skill3Icon.Visible = 'off';
                    end
                else
                    % 可用 - 不顯示數字，顯示圖片
                    obj.Skill3Label.Text = '';
                    obj.Skill3Label.BackgroundColor = [0.1, 0.1, 0.4];
                    obj.Skill3Label.Visible = 'off';

                    if isvalid(obj.Skill3Icon)
                        obj.Skill3Icon.Visible = 'on';
                    end
                end
            end
        end
        function destroyAllEnemies(obj)
            % 清除所有敵人
            if isempty(obj.Enemies)
                return;
            end

            % 創建視覺效果 - 所有敵人同時閃爍
            for i = 1:length(obj.Enemies)
                if isvalid(obj.Enemies(i).Graphic)
                    originalColor = obj.Enemies(i).Graphic.FaceColor;
                    obj.Enemies(i).Graphic.FaceColor = [1, 1, 1]; % 白色閃爍
                end
            end

            % 短暫停頓顯示效果
            pause(0.1);

            % 檢查是否有boss並記錄
            hasBoss = false;
            for i = 1:length(obj.Enemies)
                if strcmp(obj.Enemies(i).Type, 'boss')
                    hasBoss = true;
                    break;
                end
            end

            % 刪除所有敵人
            for i = 1:length(obj.Enemies)
                if isvalid(obj.Enemies(i).Graphic)
                    delete(obj.Enemies(i).Graphic);
                end
                if isfield(obj.Enemies(i), 'SkillWarning') && ...
                        ~isempty(obj.Enemies(i).SkillWarning) && ...
                        isgraphics(obj.Enemies(i).SkillWarning)
                    delete(obj.Enemies(i).SkillWarning);
                end
            end

            % 清空敵人陣列
            obj.Enemies = [];

            % 只有當boss存在並被殺死時才觸發勝利
            if hasBoss
                obj.showVictoryScreen();
            end
        end

        function loadSkill1Frames(obj)
            % 載入Effect.png第26行第1-9列
            try
                effectPath = fullfile(obj.basePath, 'images', 'skill', 'Effect.png');
                [effectSheet, ~, effectAlpha] = imread(effectPath);

                % Effect.png 是30行×9列的sheet
                numColumns = 9;
                numRows = 30;
                targetRow = 26; % 第26行
                numFrames = 9; % 第1到第9列，共九張圖片

                frameWidth = floor(size(effectSheet, 2)/numColumns);
                frameHeight = floor(size(effectSheet, 1)/numRows);

                obj.Skill1Frames = cell(1, numFrames);

                for frame = 1:numFrames
                    % 計算第26行第frame列的位置
                    startY = floor((targetRow - 1)*frameHeight) + 1;
                    startX = floor((frame - 1)*frameWidth) + 1;
                    endY = min(startY+frameHeight-1, size(effectSheet, 1));
                    endX = min(startX + frameWidth - 1, size(effectSheet, 2));

                    % 提取幀
                    frameImg = effectSheet(startY:endY, startX:endX, :);

                    % 處理alpha通道
                    if ~isempty(effectAlpha)
                        frameAlpha = effectAlpha(startY:endY, startX:endX);
                    else
                        frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                    end

                    % 翻轉圖像（與爆炸動畫保持一致）
                    frameImg = flipud(frameImg);
                    frameAlpha = flipud(frameAlpha);

                    obj.Skill1Frames{frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                end

            catch ME
                warning(ME.identifier, '載入技能1動畫失敗：%s', ME.message);
                % 創建備用的效果
                obj.Skill1Frames = {};
                for i = 1:9
                    % 創建漸變的黃色圓形作為備用
                    img = ones(100, 100, 3, 'uint8');
                    intensity = (10 - i) / 9; % 逐漸減弱
                    img(:, :, 1) = uint8(255*intensity); % Red
                    img(:, :, 2) = uint8(255*intensity); % Green (Yellow)
                    img(:, :, 3) = uint8(0); % Blue
                    alpha = ones(100, 100) * intensity;
                    obj.Skill1Frames{i} = struct('Image', img, 'Alpha', alpha);
                end
            end
        end

        function updateEnemySpawning(obj, deltaTime)
            % 更新生成計時器
            obj.EnemySpawnTimer = obj.EnemySpawnTimer + deltaTime;

            % 檢查是否該生成新敵人
            if obj.EnemySpawnTimer >= obj.EnemySpawnInterval && length(obj.Enemies) < obj.MaxEnemies
                obj.spawnEnemyAtEdge();
                obj.EnemySpawnTimer = 0; % 重置計時器
            end
        end
        function spawnEnemyAtEdge(obj)
            % 計算四個邊的總長度
            totalPerimeter = 2 * (obj.gameWidth + obj.gameHeight);

            % 隨機選擇邊緣上的一點
            randomPoint = randi(totalPerimeter);

            if randomPoint <= obj.gameWidth
                % 上邊緣
                spawnX = randomPoint;
                spawnY = obj.gameHeight + obj.SpawnMargin;

            elseif randomPoint <= obj.gameWidth + obj.gameHeight
                % 右邊緣
                spawnX = obj.gameWidth + obj.SpawnMargin;
                spawnY = randomPoint - obj.gameWidth;

            elseif randomPoint <= 2 * obj.gameWidth + obj.gameHeight
                % 下邊緣
                spawnX = obj.gameWidth - (randomPoint - obj.gameWidth - obj.gameHeight);
                spawnY = -obj.SpawnMargin;

            else
                % 左邊緣
                spawnX = -obj.SpawnMargin;
                spawnY = obj.gameHeight - (randomPoint - 2 * obj.gameWidth - obj.gameHeight);
            end

            % 創建新敵人
            obj.createNewEnemy([spawnX, spawnY]);
        end


        function createNewEnemy(obj, position)
            % 創建新敵人結構
            newEnemy = struct( ...
                'Type', 'melee', ...
                'Position', position, ...
                'Health', 1314, ...
                'Attack', 520, ...
                'AttackRange', 50, ...
                'AttackCooldown', 0, ...
                'SkillCooldown', 0, ...
                'SkillMaxCooldown', 0, ...
                'SkillWarning', [], ...
                'SkillWarningTimer', 0, ...
                'PoisonSlowed', false, ...
                'SlowTimer', 0, ...
                'Graphic', []);

            % 創建圖形
            newEnemy.Graphic = rectangle(obj.GameAxes, ...
                'Position', [0, 0, 30, 30], ...
                'FaceColor', 'r');

            % 更新位置
            updatePosition(newEnemy.Graphic, newEnemy.Position);

            % 添加到敵人陣列
            if isempty(obj.Enemies)
                obj.Enemies = newEnemy;
            else
                obj.Enemies(end+1) = newEnemy;
            end

            fprintf('新敵人在位置 [%.1f, %.1f] 生成\n', position(1), position(2));
        end


    end
end

% 更新位置輔助函數
function updatePosition(graphicObj, pos)
try
    if ~isvalid(graphicObj)
        warning('嘗試更新無效的圖形對象');

        return;
    end

    % 取得目前的寬高
    rectPos = graphicObj.Position;
    width = rectPos(3);
    height = rectPos(4);

    % 設定新位置
    graphicObj.Position = [pos(1) - width / 2, pos(2) - height / 2, width, height];
catch
    % 忽略錯誤，防止崩潰
end
end
