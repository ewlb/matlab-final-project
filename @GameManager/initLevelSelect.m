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
    
    % % 返回按鈕區域
    backGrid = uigridlayout(mainGrid, [1 3]);
    backGrid.Padding = [0 100 0 100];
    backGrid.BackgroundColor = [0.1 0.1 0.4];
    backGrid.Layout.Row = 3;
    backGrid.Layout.Column = 1;

    backBtn = uibutton(backGrid, 'push');
    backBtn.Text = '返回主畫面';
    backBtn.Layout.Column = 2; % important
    backBtn.FontSize = 1*-1+45-14; % 30
    backBtn.BackgroundColor = [0.8 0.2 0.2];
    backBtn.FontColor = 'w';
    backBtn.ButtonPushedFcn = @(src,event) obj.switchPanel('main');


end