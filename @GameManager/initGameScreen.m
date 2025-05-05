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
    
    % 添加時間標籤
    obj.TimeLabel = uilabel(obj.MainFig);
    obj.TimeLabel.Text = '時間: 00:00';
    obj.TimeLabel.Position = [50 obj.ScreenHeight-50 200 30]; 
    obj.TimeLabel.FontSize = 18;
    obj.TimeLabel.FontColor = 'w';
    obj.TimeLabel.BackgroundColor = [0.1 0.1 0.4];


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