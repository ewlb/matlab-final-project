%  modify from initpausemenu
function initGameOverScreen(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            gameOverContainer = uipanel(obj.GameOverPanel,...
                'Position', [(obj.gameWidth-300)/2 (obj.gameHeight-300)/2 300 300],...
                'BackgroundColor', [0.3 0.3 0.3]);

            % 暫停標籤
            uilabel(gameOverContainer,...
                'Text', 'YOU ARE SO DEAD',...
                'Position', [0 250 300 40],...
                'FontSize', 24,...
                'FontColor', 'w',...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 重新按鈕
            retryBtn = uibutton(gameOverContainer, 'push',...
                'Text', '重玩',...
                'Position', [50 200 200 60],...
                'BackgroundColor', [0.2 0.6 0.2],...
                'ButtonPushedFcn', @(src,event) obj.retry(),... % TODO: add retry()/restart() at gamemanager
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(gameOverContainer, 'push',...
                'Text', '返回主畫面',...
                'Position', [50 110 200 60],...
                'BackgroundColor', [0.2 0.2 0.6],...
                'ButtonPushedFcn', @(src,event) obj.switchPanel('main'),...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(gameOverContainer, 'push',...
                'Text', '離開遊戲',...
                'Position', [50 20 200 60],...
                'BackgroundColor', [0.6 0.2 0.2],...
                'ButtonPushedFcn', @(src,event) obj.quitGame(),...
                btnStyle{:});
end

% 遊戲結束畫面（新增）
        % function initGameOverScreen(obj)
        %     % 清除舊元素
        %     delete(findobj(obj.GameOverPanel, 'Type', 'UIControl'));
        %     delete(findobj(obj.GameOverPanel, 'Type', 'UILabel'));
        % 
        %     % 確保GameOverPanel在最上層
        %     uistack(obj.GameOverPanel, 'top');
        % 
        %     % 失敗文字
        %     gameOverLabel = uilabel(obj.GameOverPanel, ...
        %         'Text', '遊戲結束', ...
        %         'FontSize', 48, ...
        %         'FontWeight', 'bold', ...
        %         'FontColor', [1 0 0], ...
        %         'Position', [obj.gameWidth/2-150, obj.gameHeight/2+100, 300, 60], ...
        %         'HorizontalAlignment', 'center', ...
        %         'Tag', 'GameOverTitle');
        % 
        %     % 玩家生命值標籤
        %     obj.GameOverScoreLabel = uilabel(obj.GameOverPanel, ...
        %         'Text', '生命值: 0', ...
        %         'FontSize', 24, ...
        %         'FontColor', 'w', ...
        %         'Position', [obj.gameWidth/2-150, obj.gameHeight/2+40, 300, 40], ...
        %         'HorizontalAlignment', 'center', ...
        %         'Tag', 'ScoreLabel');
        % 
        %     % 按鈕添加Tag以便日後參考
        %     restartBtn = uibutton(obj.GameOverPanel, 'push', ...
        %         'Text', '重新開始', ...
        %         'FontSize', 24, ...
        %         'BackgroundColor', [0.3 0.6 0.3], ...
        %         'FontColor', 'w', ...
        %         'Position', [obj.gameWidth/2-150, obj.gameHeight/2-30, 300, 60], ...
        %         'ButtonPushedFcn', @(src,event) obj.restartLevel(), ...
        %         'Tag', 'RestartButton');
        % 
        %     % 返回主菜單按鈕
        %     mainMenuBtn = uibutton(obj.GameOverPanel, 'push', ...
        %         'Text', '返回主畫面', ...
        %         'FontSize', 24, ...
        %         'BackgroundColor', [0.2 0.2 0.6], ...
        %         'FontColor', 'w', ...
        %         'Position', [obj.gameWidth/2-150, obj.gameHeight/2-100, 300, 60], ...
        %         'ButtonPushedFcn', @(src,event) obj.switchPanel('main'), ...
        %         'Tag', 'MainMenuButton');
        % end