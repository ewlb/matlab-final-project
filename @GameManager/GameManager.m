classdef GameManager < handle
    properties
        % 遊戲狀態與視窗管理
        MainFig         % 主視窗
        MainPanel       % 主選單面板
        LevelPanel      % 關卡選擇面板
        GamePanel       % 遊戲面板
        HelpPanel       % 說明面板
        PausePanel      % 暫停面板 (新增)
        GameOverPanel   % 遊戲結束面板 (新增)
        CurrentPanel    % 當前顯示的面板
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
        Bullets = struct('Position', {}, 'Velocity', {}, 'Speed', {}, 'Graphic', {})
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

        TimeLabel       % 時間顯示標籤
        GameTimer       % 遊戲計時器
        ElapsedTime = 0 % 累計時間(秒)
        TimeStr = '00:00' % 時間顯示字串

    end

    methods
        function obj = GameManager()
            % 創建唯一的主視窗並設置背景
            obj.MainFig = uifigure('Name', '太空射擊遊戲');
            obj.MainFig.WindowState = 'fullscreen';
            obj.MainFig.Color = [0.1 0.1 0.4];

            % 取得螢幕大小
            screenSize = get(0, 'ScreenSize');
            obj.ScreenWidth = screenSize(3);
            obj.ScreenHeight = screenSize(4);

            % 預加載所有面板
            obj.MainPanel = uipanel(obj.MainFig, 'Position', [0 0 obj.ScreenWidth obj.ScreenHeight], 'Visible', 'on', 'BackgroundColor', [0.1 0.1 0.4]);
            obj.LevelPanel = uipanel(obj.MainFig, 'Position', [0 0 obj.ScreenWidth obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1 0.1 0.4]);
            obj.HelpPanel = uipanel(obj.MainFig, 'Position', [0 0 obj.ScreenWidth obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1 0.1 0.4]);

            % 計算位置
            xOffset = (obj.ScreenWidth - obj.gameWidth) / 2;
            yOffset = (obj.ScreenHeight - obj.gameHeight) / 2;

            % 遊戲相關面板
            obj.GamePanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0.1 0.1 0.4]);
            obj.PausePanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0 0 0 0.5]);
            obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0 0 0 0.8]);

            % 初始化所有面板內容
            obj.initMainMenu();
            obj.initLevelSelect();
            obj.initHelpScreen();
            obj.initPauseMenu();    % 新增
            obj.initGameOverScreen(); % 新增

            % 設置當前面板
            obj.CurrentPanel = obj.MainPanel;

            % 設置窗口關閉時的清理函數
            obj.MainFig.CloseRequestFcn = @(src,event) obj.cleanup();
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
            if strcmp(fromState, 'PAUSED')
                if strcmp(toPanel, 'game')
                    % 從暫停返回遊戲，重啟計時器
                    if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                        start(obj.Timer);
                    end
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
            obj.GameTimer = timer(...
                'ExecutionMode', 'fixedRate',...
                'Period', 1,...
                'TimerFcn', @(src,event) obj.updateTimer(),...
                'BusyMode', 'drop');
            start(obj.GameTimer);
        end

        % 暫停功能
        function togglePause(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                % 暫停遊戲
                obj.isPaused = true;
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
                    start(obj.Timer);  % 只有計時器未運行時才啟動
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
                obj.MousePos = cp(1,1:2);
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
                    obj.fireBullet(obj.Player.Position, direction);
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
                        obj.Player.Graphic = rectangle(obj.GameAxes, 'Position',[0 0 30 30],...
                            'FaceColor','b');
                        updatePosition(obj.Player.Graphic, obj.Player.Position);
                    end

                    % 檢查敵人圖形是否有效
                    for i = 1:length(obj.Enemies)
                        if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
                            % 重建敵人圖形
                            obj.Enemies(i).Graphic = rectangle(obj.GameAxes, 'Position',[0 0 30 30],...
                                'FaceColor','r');
                            updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                        end
                    end

                    % 更新遊戲邏輯
                    obj.updateBullets();
                    obj.checkBulletCollisions();
                    obj.updateEnemies();
                    obj.resolveEnemyCollisions();
                    obj.checkPlayerEnemyCollision();

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
                    drawnow 
                end
            catch ME
                disp(['遊戲循環錯誤: ' ME.message]);
                disp(getReport(ME));
            end
        end

        % 顯示遊戲結束畫面
        % should be modified from togglePause
        function showGameOverScreen(obj)

            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.isPaused = true;
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
            halfSize1 = size1/2;
            halfSize2 = size2/2;

            collision = abs(pos1(1) - pos2(1)) < (halfSize1 + halfSize2) && ...
                abs(pos1(2) - pos2(2)) < (halfSize1 + halfSize2);
        end
        
        initMainMenu(obj)
        initHelpScreen(obj)
        initLevelSelect(obj)
        initGameScreen(obj, levelNum)
        initPauseMenu(obj)
        initGameOverScreen(obj)   
        initPlayer(obj)
        initEnemies(obj, levelNum)
        handleKeyPress(obj, event)
        updateBullets(obj)
        updateEnemies(obj)
        checkBulletCollisions(obj)
        resolveEnemyCollisions(obj)
        checkPlayerEnemyCollision(obj)
        fireBullet(obj, startPos, direction)
        removeBullets(obj, indices)
        removeEnemies(obj, indices)
        cleanupGameState(obj)
    end
end


