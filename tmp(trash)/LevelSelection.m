% classdef LevelSelection < handle
%     properties
%         SelectionFig
%         BackBtn
%         LevelButtons
%     end
% 
%     methods
%         function obj = LevelSelection()
%             % 初始化主容器
%             obj.SelectionFig = uifigure('Name', '關卡選擇', 'Position', [100 100 800 600]);
%             obj.SelectionFig.Color = [0.1 0.1 0.4];
% 
%             % 主網格佈局 (3行1列)
%             mainGrid = uigridlayout(obj.SelectionFig, [3 1]);
%             mainGrid.RowHeight = {'fit', '1x', 'fit'};
%             mainGrid.ColumnWidth = {'1x'};
%             mainGrid.BackgroundColor = [0.1 0.1 0.4];
% 
%             % 標題區域
%             titleLbl = uilabel(mainGrid);
%             titleLbl.Text = '選擇關卡';
%             titleLbl.FontSize = 36;
%             titleLbl.FontColor = 'w';
%             titleLbl.HorizontalAlignment = 'center';
%             titleLbl.Layout.Row = 1;
%             titleLbl.Layout.Column = 1;
%             % titleLbl.BackgroundColor = [0.1 0.1 0.4];
% 
%             % 關卡按鈕容器 (使用網格佈局)
%             btnGrid = uigridlayout(mainGrid, [1 3]);
%             btnGrid.Padding = [50 0 50 0];
%             btnGrid.Layout.Row = 2;
%             btnGrid.Layout.Column = 1;
%             btnGrid.BackgroundColor = [0.1 0.1 0.4];
% 
%             % 三個關卡按鈕
%             obj.LevelButtons = gobjects(1,3);
%             for i = 1:3
%                 obj.LevelButtons(i) = uibutton(btnGrid, 'push');
%                 obj.LevelButtons(i).Text = sprintf('第 %d 關', i);
%                 obj.LevelButtons(i).FontSize = 24;
%                 obj.LevelButtons(i).BackgroundColor = [0.3 0.7 0.5];
%                 obj.LevelButtons(i).FontColor = 'w';
%                 obj.LevelButtons(i).ButtonPushedFcn = @(src,event) obj.startLevel(i);
%             end
% 
%             % 返回按鈕區域
%             backPanel = uipanel(mainGrid);
%             backPanel.BackgroundColor = [0.1 0.1 0.4];
%             backPanel.Layout.Row = 3;
%             backPanel.Layout.Column = 1;
% 
%             obj.BackBtn = uibutton(backPanel, 'push');
%             obj.BackBtn.Text = '返回主畫面';
%             obj.BackBtn.Position = [300 10 200 40];
%             obj.BackBtn.FontSize = 18;
%             obj.BackBtn.BackgroundColor = [0.8 0.2 0.2];
%             obj.BackBtn.FontColor = 'w';
%             obj.BackBtn.ButtonPushedFcn = @(src,event) obj.backToMain();
%         end
% 
%         function startLevel(obj, levelNum)
%             delete(obj.SelectionFig);
%             GameScreen(levelNum);
%         end
% 
%         function backToMain(obj)
%             delete(obj.SelectionFig);
%             ShootingGame();
%         end
%     end
% end
