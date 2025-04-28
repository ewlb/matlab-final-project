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
        GameOverScoreLabel
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

        % 暫停界面元素
        PauseMenuPanel
        ResumeBtn
        MainMenuBtn
        QuitBtn

        % 遊戲設定
        isPaused = false
        AxesXLim
        AxesYLim
        CurrentLevel

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

            % 隱藏當前面板 不能改
            obj.CurrentPanel.Visible = 'off';

            % % 保存當前視窗狀態
            % currentState = obj.MainFig.WindowState;

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


        %     % 處理面板切換前的清理工作
        %     if obj.CurrentPanel == obj.GamePanel && ~strcmp(panelName, 'game')
        %         % 離開遊戲面板前先檢查狀態
        %         if strcmp(obj.GameState, 'GAME_OVER')
        %             % 清理死亡畫面
        %             if ~isempty(obj.GameOverPanel) && isvalid(obj.GameOverPanel)
        %                 delete(obj.GameOverPanel);
        %                 obj.GameOverPanel = [];
        %             end
        %         end
        %
        %         % 停止遊戲循環
        %         if ~isempty(obj.Timer) && isvalid(obj.Timer)
        %             try
        %                 stop(obj.Timer);
        %                 delete(obj.Timer);
        %             catch
        %                 % 忽略錯誤
        %             end
        %             obj.Timer = [];
        %         end
        %
        %         % 徹底清理遊戲狀態
        %         obj.cleanupGameState();
        %         obj.GameState = 'MAIN_MENU';
        %     end
        %
        %     % 隱藏當前面板
        %     obj.CurrentPanel.Visible = 'off';
        %
        %     % 顯示目標面板
        %     switch panelName
        %         case 'main'
        %             obj.CurrentPanel = obj.MainPanel;
        %             obj.GameState = 'MAIN_MENU';
        %         case 'level'
        %             obj.CurrentPanel = obj.LevelPanel;
        %             obj.GameState = 'LEVEL_SELECT';
        %         case 'game'
        %             obj.CurrentPanel = obj.GamePanel;
        %             obj.GameState = 'PLAYING';
        %
        %             % 進入遊戲面板時確保計時器存在並運行
        %             if isempty(obj.Timer) || ~isvalid(obj.Timer)
        %                 obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016,...
        %                     'TimerFcn', @(src,event) obj.gameLoop());
        %             end
        %
        %             if strcmp(get(obj.Timer, 'Running'), 'off')
        %                 start(obj.Timer);
        %             end
        %         case 'help'
        %             obj.CurrentPanel = obj.HelpPanel;
        %             obj.GameState = 'HELP';
        %     end
        %
        %     obj.CurrentPanel.Visible = 'on';
        %
        %     % 恢復視窗狀態
        %     obj.MainFig.WindowState = currentState;
        % end
        % 狀態轉換處理（新增）
        function handleStateTransition(obj, fromState, toPanel)
            % 處理不同狀態間的轉換邏輯

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

        function cleanupGameState(obj)
            % 重置遊戲狀態
            obj.isPaused = false;

            % 清理暫停菜單界面
            if ~isempty(obj.PauseMenuPanel) && isfield(obj.PauseMenuPanel, 'Parent') && isvalid(obj.PauseMenuPanel.Parent)
                delete(obj.PauseMenuPanel.Parent);
                obj.PauseMenuPanel = [];
            end

            % 清理死亡畫面
            if ~isempty(obj.GameOverPanel) && isvalid(obj.GameOverPanel)
                delete(obj.GameOverPanel);
                obj.GameOverPanel = [];
            end

            % 清理遊戲對象
            if ~isempty(obj.Bullets)
                for i = 1:length(obj.Bullets)
                    if isfield(obj.Bullets(i), 'Graphic') && isvalid(obj.Bullets(i).Graphic)
                        delete(obj.Bullets(i).Graphic);
                    end
                end
                obj.Bullets = struct('Position', {}, 'Velocity', {}, 'Speed', {}, 'Graphic', {});
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

            % 清理敵人與玩家
            if ~isempty(obj.Enemies)
                for i = 1:length(obj.Enemies)
                    if isfield(obj.Enemies(i), 'Graphic') && isvalid(obj.Enemies(i).Graphic)
                        delete(obj.Enemies(i).Graphic);
                    end
                end
            end
            obj.Enemies = struct();

            if isfield(obj, 'Player') && ~isempty(obj.Player) && isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                delete(obj.Player.Graphic);
            end
            obj.Player = [];
        end

        % 各畫面初始化函數
        function initMainMenu(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            % 遊戲標題
            titleLbl = uilabel(obj.MainPanel);
            titleLbl.Text = '太空射擊戰';
            titleLbl.FontSize = 48;
            titleLbl.FontColor = 'w';
            titleLbl.Position = [centerX-200 centerY+150 400 60];

            % 遊戲開始按鈕
            startBtn = uibutton(obj.MainPanel, 'push');
            startBtn.Text = '開始遊戲';
            startBtn.Position = [centerX-100 centerY 200 60];
            startBtn.FontSize = 24;
            startBtn.BackgroundColor = [0.2 0.6 1];
            startBtn.FontColor = 'w';
            startBtn.ButtonPushedFcn = @(src,event) obj.switchPanel('level');

            % 遊戲說明按鈕
            helpBtn = uibutton(obj.MainPanel, 'push');
            helpBtn.Text = '遊戲說明';
            helpBtn.Position = [centerX-100 centerY-100 200 60];
            helpBtn.FontSize = 24;
            helpBtn.BackgroundColor = [0.2 0.6 1];
            helpBtn.FontColor = 'w';
            helpBtn.ButtonPushedFcn = @(src,event) obj.switchPanel('help');
        end

        function initLevelSelect(obj)
            % 主網格佈局
            mainGrid = uigridlayout(obj.LevelPanel, [3 1]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.BackgroundColor = [0.1 0.1 0.4];

            % 標題區域
            titleLbl = uilabel(mainGrid);
            titleLbl.Text = '選擇關卡';
            titleLbl.FontSize = 36;
            titleLbl.FontColor = 'w';
            titleLbl.HorizontalAlignment = 'center';
            titleLbl.Layout.Row = 1;
            titleLbl.Layout.Column = 1;

            % 關卡按鈕容器
            btnGrid = uigridlayout(mainGrid, [1 3]);
            btnGrid.Padding = [50 0 50 0];
            btnGrid.Layout.Row = 2;
            btnGrid.Layout.Column = 1;
            btnGrid.BackgroundColor = [0.1 0.1 0.4];

            % 三個關卡按鈕
            for i = 1:3
                btn = uibutton(btnGrid, 'push');
                btn.Text = sprintf('第 %d 關', i);
                btn.FontSize = 24;
                btn.BackgroundColor = [0.3 0.7 0.5];
                btn.FontColor = 'w';
                btn.ButtonPushedFcn = @(src,event) obj.startLevel(i);
            end

            % 返回按鈕區域
            backPanel = uipanel(mainGrid);
            backPanel.BackgroundColor = [0.1 0.1 0.4];
            backPanel.Layout.Row = 3;
            backPanel.Layout.Column = 1;

            % 獲取backPanel的寬度
            backPanelWidth = obj.ScreenWidth;

            backBtn = uibutton(backPanel, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Position = [(backPanelWidth/2)-100 10 200 40];
            backBtn.FontSize = 18;
            backBtn.BackgroundColor = [0.8 0.2 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src,event) obj.switchPanel('main');
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
            titleLbl.Position = [centerX-100 centerY+150 200 40];

            % 說明內容
            instructLbl = uilabel(obj.HelpPanel);
            instructLbl.Text = sprintf('%s\n%s\n%s','移動: WASD鍵','射擊: 滑鼠左鍵', '暫停: p鍵');
            instructLbl.WordWrap = 'on';
            instructLbl.FontSize = 24;
            instructLbl.FontColor = 'w';
            instructLbl.Position = [centerX-150 centerY-50 300 300];

            % 返回按鈕
            backBtn = uibutton(obj.HelpPanel, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Position = [centerX-100 centerY-150 200 50];
            backBtn.FontSize = 18;
            backBtn.BackgroundColor = [0.8 0.2 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src,event) obj.switchPanel('main');
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
        end

        function initGameScreen(obj, levelNum)
            % 清理舊的遊戲元素
            obj.cleanupGameState();
            delete(findobj(obj.GamePanel, 'Type', 'UIAxes'));

            % 創建遊戲畫布
            obj.GameAxes = uiaxes(obj.GamePanel);
            obj.GameAxes.Position = [0 0 obj.gameWidth obj.gameHeight];

            % 更新遊戲限制範圍
            obj.AxesXLim = [0 obj.gameWidth];
            obj.AxesYLim = [0 obj.gameHeight];

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
            pauseBtn.Position = [obj.gameWidth-70 obj.gameHeight-50 40 40];
            pauseBtn.FontSize = 24;
            pauseBtn.BackgroundColor = [0.9 0.9 0.9];
            pauseBtn.ButtonPushedFcn = @(src,event) obj.togglePause();

            % 設置控制監聽
            set(obj.MainFig, 'KeyPressFcn', @(src,event) obj.handleKeyPress(event));
            set(obj.MainFig, 'WindowButtonMotionFcn', @(src,event) obj.trackMousePosition());
            set(obj.MainFig, 'WindowButtonDownFcn', @(src,event) obj.handleMouseClick());

            % 初始化遊戲元素
            obj.initPlayer();
            obj.initEnemies(levelNum);

            % 創建玩家生命與攻擊力顯示
            obj.HealthLabel = uilabel(obj.MainFig);
            obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
            obj.HealthLabel.Position = [50 obj.ScreenHeight-100 200 30];
            obj.HealthLabel.FontSize = 18;
            obj.HealthLabel.FontColor = 'w';
            obj.HealthLabel.BackgroundColor = [0.1 0.1 0.4];

            obj.AttackLabel = uilabel(obj.MainFig);
            obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
            obj.AttackLabel.Position = [50 obj.ScreenHeight-150 200 30];
            obj.AttackLabel.FontSize = 18;
            obj.AttackLabel.FontColor = 'w';
            obj.AttackLabel.BackgroundColor = [0.1 0.1 0.4];

            % 確保計時器處於運行狀態
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016,...
                    'TimerFcn', @(src,event) obj.gameLoop());
            end

            if strcmp(get(obj.Timer, 'Running'), 'off')
                start(obj.Timer);
            end
        end
        % 初始化暫停選單（新增）
        function initPauseMenu(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            menuContainer = uipanel(obj.PausePanel,...
                'Position', [(obj.gameWidth-300)/2 (obj.gameHeight-300)/2 300 300],...
                'BackgroundColor', [0.3 0.3 0.3]);

            % 暫停標籤
            uilabel(menuContainer,...
                'Text', '遊戲已暫停',...
                'Position', [50 250 200 40],...
                'FontSize', 24,...
                'FontColor', 'w',...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 繼續按鈕
            resumeBtn = uibutton(menuContainer, 'push',...
                'Text', '繼續遊戲',...
                'Position', [50 200 200 60],...
                'BackgroundColor', [0.2 0.6 0.2],...
                'ButtonPushedFcn', @(src,event) obj.togglePause(),...
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(menuContainer, 'push',...
                'Text', '返回主畫面',...
                'Position', [50 110 200 60],...
                'BackgroundColor', [0.2 0.2 0.6],...
                'ButtonPushedFcn', @(src,event) obj.switchPanel('main'),...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(menuContainer, 'push',...
                'Text', '離開遊戲',...
                'Position', [50 20 200 60],...
                'BackgroundColor', [0.6 0.2 0.2],...
                'ButtonPushedFcn', @(src,event) obj.quitGame(),...
                btnStyle{:});
        end
        % 遊戲結束畫面（新增）
        function initGameOverScreen(obj)
            % 清除舊元素
            delete(findobj(obj.GameOverPanel, 'Type', 'UIControl'));
            delete(findobj(obj.GameOverPanel, 'Type', 'UILabel'));

            % 確保GameOverPanel在最上層
            uistack(obj.GameOverPanel, 'top');

            % 失敗文字
            gameOverLabel = uilabel(obj.GameOverPanel, ...
                'Text', '遊戲結束', ...
                'FontSize', 48, ...
                'FontWeight', 'bold', ...
                'FontColor', [1 0 0], ...
                'Position', [obj.gameWidth/2-150, obj.gameHeight/2+100, 300, 60], ...
                'HorizontalAlignment', 'center', ...
                'Tag', 'GameOverTitle');

            % 玩家生命值標籤
            obj.GameOverScoreLabel = uilabel(obj.GameOverPanel, ...
                'Text', '生命值: 0', ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'Position', [obj.gameWidth/2-150, obj.gameHeight/2+40, 300, 40], ...
                'HorizontalAlignment', 'center', ...
                'Tag', 'ScoreLabel');

            % 按鈕添加Tag以便日後參考
            restartBtn = uibutton(obj.GameOverPanel, 'push', ...
                'Text', '重新開始', ...
                'FontSize', 24, ...
                'BackgroundColor', [0.3 0.6 0.3], ...
                'FontColor', 'w', ...
                'Position', [obj.gameWidth/2-150, obj.gameHeight/2-30, 300, 60], ...
                'ButtonPushedFcn', @(src,event) obj.restartLevel(), ...
                'Tag', 'RestartButton');

            % 返回主菜單按鈕
            mainMenuBtn = uibutton(obj.GameOverPanel, 'push', ...
                'Text', '返回主畫面', ...
                'FontSize', 24, ...
                'BackgroundColor', [0.2 0.2 0.6], ...
                'FontColor', 'w', ...
                'Position', [obj.gameWidth/2-150, obj.gameHeight/2-100, 300, 60], ...
                'ButtonPushedFcn', @(src,event) obj.switchPanel('main'), ...
                'Tag', 'MainMenuButton');
        end


        % % 暫停相關功能
        % function togglePause(obj)
        %     % 保存當前窗口狀態
        %     currentState = obj.MainFig.WindowState;
        %
        %     obj.isPaused = ~obj.isPaused;
        %     if obj.isPaused
        %         if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'on')
        %             stop(obj.Timer);
        %         end
        %         obj.showPauseMenu();
        %     else
        %         if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
        %             start(obj.Timer);
        %         end
        %         obj.hidePauseMenu();
        %     end
        %
        %     % 確保窗口狀態保持不變
        %     obj.MainFig.WindowState = currentState;
        % end
        % 暫停功能
        function togglePause(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                % 暫停遊戲
                obj.isPaused = true;
                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                end
                obj.switchPanel('pause');
            elseif obj.isPaused && strcmp(obj.GameState, 'PAUSED')
                % 恢復遊戲
                obj.isPaused = false;
                obj.switchPanel('game');
                if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                    start(obj.Timer);  % 只有計時器未運行時才啟動
                end
            end
        end

        % function showPauseMenu(obj)
        %     % 半透明遮罩層
        %     mask = uipanel(obj.GamePanel,...
        %         'BackgroundColor', [0 0 0 0.5],...
        %         'Position', [0 0 obj.gameWidth obj.gameHeight]);
        %
        %     % 暫停選單容器
        %     obj.PauseMenuPanel = uipanel(mask,...
        %         'Position', [(obj.gameWidth-300)/2 (obj.gameHeight-300)/2 300 300],...
        %         'BackgroundColor', [0.3 0.3 0.3]);
        %
        %     % 暫停標籤
        %     uilabel(obj.PauseMenuPanel,...
        %         'Text', '遊戲已暫停',...
        %         'Position', [50 250 200 40],...
        %         'FontSize', 24,...
        %         'FontColor', 'w',...
        %         'HorizontalAlignment', 'center');
        %
        %     % 按鈕樣式設定
        %     btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};
        %
        %     % 繼續按鈕
        %     obj.ResumeBtn = uibutton(obj.PauseMenuPanel, 'push',...
        %         'Text', '繼續遊戲',...
        %         'Position', [50 200 200 60],...
        %         'BackgroundColor', [0.2 0.6 0.2],...
        %         'ButtonPushedFcn', @(src,event) obj.togglePause(),...
        %         btnStyle{:});
        %
        %     % 主選單按鈕
        %     obj.MainMenuBtn = uibutton(obj.PauseMenuPanel, 'push',...
        %         'Text', '返回主畫面',...
        %         'Position', [50 110 200 60],...
        %         'BackgroundColor', [0.2 0.2 0.6],...
        %         'ButtonPushedFcn', @(src,event) obj.backToMainMenu(),...
        %         btnStyle{:});
        %
        %     % 離開遊戲按鈕
        %     obj.QuitBtn = uibutton(obj.PauseMenuPanel, 'push',...
        %         'Text', '離開遊戲',...
        %         'Position', [50 20 200 60],...
        %         'BackgroundColor', [0.6 0.2 0.2],...
        %         'ButtonPushedFcn', @(src,event) obj.quitGame(),...
        %         btnStyle{:});
        % end

        % function hidePauseMenu(obj)
        %     if ~isempty(obj.PauseMenuPanel) && isfield(obj.PauseMenuPanel, 'Parent') && isvalid(obj.PauseMenuPanel.Parent)
        %         delete(obj.PauseMenuPanel.Parent);
        %         obj.PauseMenuPanel = [];
        %     end
        % end

        % function backToMainMenu(obj)
        %     % 先隱藏暫停菜單
        %     obj.hidePauseMenu();
        %
        %     % 改變狀態為非暫停
        %     obj.isPaused = false;
        %
        %     % 切換到主畫面
        %     obj.switchPanel('main');
        % end

        function quitGame(obj)
            obj.cleanup();
        end

        % 遊戲內容初始化
        function initPlayer(obj)
            % 玩家角色初始化
            obj.Player = struct(...
                'Position', [400 50],...
                'Size', 30,...
                'Health', 1314,...
                'Attack', 520,...
                'Graphic', []);

            % 創建玩家圖形
            obj.Player.Graphic = rectangle(obj.GameAxes, 'Position',[0 0 30 30],...
                'FaceColor','b');

            % 更新位置
            updatePosition(obj.Player.Graphic, obj.Player.Position);
        end

        function initEnemies(obj, levelNum)
            obj.Enemies = struct();

            switch levelNum
                case 1
                    % 近戰敵人配置
                    for i = 1:3
                        obj.Enemies(i).Type = 'melee';
                        obj.Enemies(i).Position = [randi([50 750]), 550];
                        obj.Enemies(i).AwarenessDistance = 300;
                        obj.Enemies(i).Health = 1314;
                        obj.Enemies(i).Attack = 520;
                        obj.Enemies(i).AttackRange = 50;
                        obj.Enemies(i).AttackCooldown = 0;
                        obj.Enemies(i).Graphic = rectangle(obj.GameAxes,...
                            'Position',[0 0 30 30], 'FaceColor','r');
                        updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                    end
            end
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

        % 遊戲逻辑
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

                    drawnow limitrate
                end
            catch ME
                disp(['遊戲循環錯誤: ' ME.message]);
                disp(getReport(ME));
            end
        end

        % 顯示遊戲結束畫面
        function showGameOverScreen(obj)
            % 更新遊戲狀態
            obj.GameState = 'GAME_OVER';
            obj.isPaused = true;

            % 停止計時器
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
            end

            % 確保GameOverPanel存在且有效
            if ~isfield(obj, 'GameOverPanel') || ~isobject(obj.GameOverPanel) || isempty(obj.GameOverPanel)
                % 重新創建GameOverPanel
                xOffset = (obj.ScreenWidth - obj.gameWidth) / 2;
                yOffset = (obj.ScreenHeight - obj.gameHeight) / 2;
                obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0 0 0 0.8]);
                obj.initGameOverScreen(); % 重新初始化
            else
                try
                    % 嘗試檢查有效性
                    if ~isvalid(obj.GameOverPanel)
                        obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0 0 0 0.8]);
                        obj.initGameOverScreen();
                    end
                catch
                    % 捕獲任何錯誤並重新創建
                    xOffset = (obj.ScreenWidth - obj.gameWidth) / 2;
                    yOffset = (obj.ScreenHeight - obj.gameHeight) / 2;
                    obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset yOffset obj.gameWidth obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0 0 0 0.8]);
                    obj.initGameOverScreen();
                end
            end


            % 先將GameOverPanel帶到最前面
            uistack(obj.GameOverPanel, 'top');

            % 直接使用GameOverScoreLabel更新生命值
            if isfield(obj, 'GameOverScoreLabel') && isvalid(obj.GameOverScoreLabel)
                obj.GameOverScoreLabel.Text = sprintf('生命值: %d', obj.Player.Health);
            else
                % 若標籤無效，重新初始化死亡畫面
                obj.initGameOverScreen();
                if isfield(obj, 'GameOverScoreLabel') && isvalid(obj.GameOverScoreLabel)
                    obj.GameOverScoreLabel.Text = sprintf('生命值: %d', obj.Player.Health);
                end
            end

            % 重置所有面板可見性
            obj.MainPanel.Visible = 'off';
            obj.LevelPanel.Visible = 'off';
            obj.HelpPanel.Visible = 'off';
            obj.GamePanel.Visible = 'off';
            obj.PausePanel.Visible = 'off';

            % 明確設置GameOverPanel為可見
            obj.GameOverPanel.Visible = 'on';
            obj.CurrentPanel = obj.GameOverPanel;

            % 強制更新UI
            drawnow;
        end


        % 重新開始遊戲
        function restartLevel(obj)
            try
                % 記錄要重新開始的關卡
                levelToRestart = obj.CurrentLevel;

                % 先轉換狀態再清理內容
                obj.GameState = 'PLAYING';

                % 保留GamePanel的引用並使其可見
                gamePanel = obj.GamePanel;

                % 停止舊計時器
                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                    delete(obj.Timer);
                    obj.Timer = [];
                end

                % 隱藏當前面板，而不刪除
                if isvalid(obj.CurrentPanel)
                    obj.CurrentPanel.Visible = 'off';
                end

                % 清理之前的狀態 - 先更新引用
                obj.CurrentPanel = gamePanel;

                % 現在安全清理遊戲狀態
                obj.cleanupGameState();

                % 重新初始化遊戲畫面
                obj.initGameScreen(levelToRestart);

                % 確保顯示遊戲面板
                obj.GamePanel.Visible = 'on';
                obj.CurrentPanel = obj.GamePanel;

                % 創建和啟動新計時器
                obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016,...
                    'TimerFcn', @(src,event) obj.gameLoop());
                start(obj.Timer);
            catch ME
                % 錯誤處理
                disp(['重啟遊戲錯誤: ' ME.message]);
                disp(getReport(ME));
            end
        end


        function gameOverToMainMenu(obj)
            try
                % 隱藏當前面板
                if isvalid(obj.CurrentPanel)
                    obj.CurrentPanel.Visible = 'off';
                end

                % 設置主菜單面板
                obj.MainPanel.Visible = 'on';
                obj.CurrentPanel = obj.MainPanel;

                % 設置狀態
                obj.GameState = 'MAIN_MENU';

                % 清理遊戲狀態
                obj.cleanupGameState();

                % 強制更新UI
                drawnow;
            catch ME
                disp(['返回主菜單錯誤: ' ME.message]);
                disp(getReport(ME));
            end
        end


        % 碰撞檢測
        function collision = checkAABBCollision(obj, pos1, size1, pos2, size2)
            % AABB 碰撞檢測
            halfSize1 = size1/2;
            halfSize2 = size2/2;

            collision = abs(pos1(1) - pos2(1)) < (halfSize1 + halfSize2) && ...
                abs(pos1(2) - pos2(2)) < (halfSize1 + halfSize2);
        end

        % 注意：以下遊戲邏輯函數需要根據實際代碼來實現，這裡省略了具體實現
        % 你需要添加或保留這些函數的完整實現
        handleKeyPress(obj, event)
        updateBullets(obj)
        updateEnemies(obj)
        checkBulletCollisions(obj)
        resolveEnemyCollisions(obj)
        checkPlayerEnemyCollision(obj)
        fireBullet(obj, startPos, direction)
        removeBullets(obj, indices)
        removeEnemies(obj, indices)
    end
end

