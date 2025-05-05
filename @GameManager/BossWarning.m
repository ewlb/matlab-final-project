function BossWarning(obj, state)
    switch state
        case 'start'
            % 只在未激活狀態下執行
            % if ~obj.BossWarningActive
                % obj.BossWarningActive = true;
                
                % 計算BOSS生成位置
                bossPos = [obj.gameWidth/2, obj.gameHeight-100];
                
                % 創建半透明紅色標記
                obj.BossWarningGraphic = rectangle(obj.GameAxes,...
                    'Position', [bossPos(1)-50 bossPos(2)-50 100 100],...
                    'FaceColor', [1 0 0],...
                    'FaceAlpha',0.3,...
                    'EdgeColor', 'none',...
                    'Curvature', 0.3);
                
                % 啟動閃爍效果
                obj.startBlink();
            % end
            
        case 'end'
            % 清除預警狀態
            % obj.BossWarningActive = false;
            
            % 移除閃爍計時器
            if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
                stop(obj.BlinkTimer);
                delete(obj.BlinkTimer);
                obj.BlinkTimer = [];
            end
            
            % 移除預警圖形
            if isvalid(obj.BossWarningGraphic)
                delete(obj.BossWarningGraphic);
                obj.BossWarningGraphic = [];
            end
    end
end