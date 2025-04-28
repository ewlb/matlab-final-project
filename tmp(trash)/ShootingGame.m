% classdef ShootingGame < handle
%     properties
%         MainFig
%         StartBtn
%         HelpBtn
%         OriginalBtnColor = [0.2 0.6 1]  % 新增屬性儲存原始顏色
%     end
% 
%     methods
%         function obj = ShootingGame()
%             % 初始化主畫面
%             obj.MainFig = uifigure('Name', '太空射擊遊戲', 'Position', [100 100 800 600]);
%             obj.MainFig.Color = [0.1 0.1 0.4];
% 
%             % 設置全局滑鼠事件監聽
%             obj.MainFig.WindowButtonDownFcn = @(src,event) obj.handleMouseDown();
%             obj.MainFig.WindowButtonUpFcn = @(src,event) obj.handleMouseUp();
% 
%             % 遊戲標題
%             titleLbl = uilabel(obj.MainFig);
%             titleLbl.Text = '太空射擊戰';
%             titleLbl.FontSize = 48;
%             titleLbl.FontColor = 'w';
%             titleLbl.Position = [200 450 400 60];
% 
%             % 遊戲開始按鈕
%             obj.StartBtn = uibutton(obj.MainFig, 'push');
%             obj.StartBtn.Text = '開始遊戲';
%             obj.StartBtn.Position = [300 300 200 60];
%             obj.StartBtn.FontSize = 24;
%             obj.StartBtn.BackgroundColor = obj.OriginalBtnColor;
%             obj.StartBtn.FontColor = 'w';
%             obj.StartBtn.ButtonPushedFcn = @(src,event) obj.startGame();
% 
%             % 遊戲說明按鈕
%             obj.HelpBtn = uibutton(obj.MainFig, 'push');
%             obj.HelpBtn.Text = '遊戲說明';
%             obj.HelpBtn.Position = [300 200 200 60];
%             obj.HelpBtn.FontSize = 24;
%             obj.HelpBtn.BackgroundColor = obj.OriginalBtnColor;
%             obj.HelpBtn.FontColor = 'w';
%             obj.HelpBtn.ButtonPushedFcn = @(src,event) obj.showHelp();
%         end
% 
%         function handleMouseDown(obj)
%             % 獲取當前滑鼠位置
%             mousePos = obj.MainFig.CurrentPoint;
% 
%             % 檢查是否在按鈕區域內
%             if isOverButton(mousePos, obj.StartBtn)
%                 obj.StartBtn.BackgroundColor = obj.OriginalBtnColor * 0.7;
%             elseif isOverButton(mousePos, obj.HelpBtn)
%                 obj.HelpBtn.BackgroundColor = obj.OriginalBtnColor * 0.7;
%             end
%             drawnow limitrate
%         end
% 
%         function handleMouseUp(obj)
%             % 恢復按鈕顏色
%             obj.StartBtn.BackgroundColor = obj.OriginalBtnColor;
%             obj.HelpBtn.BackgroundColor = obj.OriginalBtnColor;
%             drawnow limitrate
%         end
% 
%         function startGame(obj)
%             delete(obj.MainFig);
%             LevelSelection();
%         end
% 
%         function showHelp(obj)
%             delete(obj.MainFig);
%             HelpScreen();
%         end
%     end
% end
% 
% % 輔助函數檢測滑鼠是否在按鈕區域內
% function result = isOverButton(mousePos, button)
%     btnPos = button.Position;
%     result = mousePos(1) >= btnPos(1) && ...
%              mousePos(1) <= (btnPos(1) + btnPos(3)) && ...
%              mousePos(2) >= btnPos(2) && ...
%              mousePos(2) <= (btnPos(2) + btnPos(4));
% end
