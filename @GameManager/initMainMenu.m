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