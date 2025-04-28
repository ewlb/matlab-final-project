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