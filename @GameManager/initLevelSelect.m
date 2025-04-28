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