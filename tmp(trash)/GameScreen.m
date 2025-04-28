% classdef GameScreen < handle
%     properties
%         GameFig
%         GameAxes
%         Player
%         Enemies
%         Bullets = struct('Position', {}, 'Velocity', {}, 'Speed', {}, 'Graphic', {})
%         Timer
%         AxesXLim = [0 800]
%         AxesYLim = [0 600]
%         MousePos = [0, 0] % 追蹤滑鼠位置
% 
%         % 暫停介面元素
%         PauseBtn
%         PauseMenuPanel
%         ResumeBtn
%         MainMenuBtn
%         QuitBtn
%         isPaused = false
%     end
% 
%     methods
%         function obj = GameScreen(levelNum)
%             % 初始化遊戲視窗
%             obj.GameFig = uifigure('Name', sprintf('第 %d 關', levelNum),...
%                 'Position', [100 100 800 600], ...
%                 'CloseRequestFcn', @(src,event) obj.cleanup());
% 
%             % 創建遊戲畫布
%             obj.GameAxes = uiaxes(obj.GameFig);
%             obj.GameAxes.Position = [0 0 800 600];
%             axis(obj.GameAxes, 'equal');
%             hold(obj.GameAxes, 'on');
% 
%             % 禁用所有預設交互功能
%             disableDefaultInteractivity(obj.GameAxes);
%             obj.GameAxes.Interactions = [];  % MATLAB R2020b+
%             obj.GameAxes.Toolbar = [];       % 隱藏坐標軸工具欄
% 
%             % 強制設定固定顯示範圍
%             xlim(obj.GameAxes, obj.AxesXLim);
%             ylim(obj.GameAxes, obj.AxesYLim);
% 
%             % 鎖定縮放與平移
%             set(obj.GameAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');
% 
%             % 初始化暫停按鈕
%             obj.PauseBtn = uibutton(obj.GameFig, 'push',...
%                 'Text', '⏸',...
%                 'Position', [730 550 40 40],...
%                 'FontSize', 24,...
%                 'BackgroundColor', [0.9 0.9 0.9],...
%                 'ButtonPushedFcn', @(src,event) obj.togglePause());
% 
%             % 初始化遊戲元素
%             obj.initPlayer();
%             obj.initEnemies(levelNum);
% 
%             % 設置控制監聽
%             set(obj.GameFig, 'KeyPressFcn', @(src,event) obj.handleKeyPress(event));
%             set(obj.GameFig, 'WindowButtonMotionFcn', @(src,event) obj.trackMousePosition());
%             set(obj.GameFig, 'WindowButtonDownFcn', @(src,event) obj.handleMouseClick());
% 
%             % 啟動遊戲循環
%             obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016,...
%                 'TimerFcn', @(src,event) obj.gameLoop());
%             start(obj.Timer);
%         end
% 
% 
% 
% 
% 
% 
% 
%         function backToMain(obj)
%             obj.cleanup();
%             ShootingGame(); % 重新啟動主畫面
%         end
% 
% 
% 
%     end
% end
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% function updatePosition(graphicObj, pos)
%     % 更新圖形物件的位置
%     % graphicObj: rectangle 物件
%     % pos: [x y] (中心座標)
% 
%     % 取得目前的寬高
%     rectPos = graphicObj.Position;
%     width = rectPos(3);
%     height = rectPos(4);
% 
%     % 設定新位置，讓中心點對齊pos
%     graphicObj.Position = [pos(1)-width/2, pos(2)-height/2, width, height];
% end
