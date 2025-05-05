function updateTimer(obj)
    THESHOWTIME = 10;
    % % 檢查
    % if ~isvalid(obj.TimeLabel)
    %     return;
    % end
    
    % 更新計時
    obj.ElapsedTime = obj.ElapsedTime + 1;
    minutes = floor(obj.ElapsedTime / 60);
    seconds = mod(obj.ElapsedTime, 60);
    
    % 格式化顯示
    obj.TimeStr = sprintf('%02d:%02d', minutes, seconds);
    
    % 更新UI（確保在主線程執行）
    if isvalid(obj.TimeLabel)
        obj.TimeLabel.Text = ['時間: ' obj.TimeStr];
    end
    if ~obj.BossAdded && obj.ElapsedTime >= THESHOWTIME && strcmp(obj.GameState, 'PLAYING')
        % 創建 BOSS 數據結構
        newBoss = struct(...
            'Type', 'boss',...
            'Position', [obj.gameWidth/2, obj.gameHeight-100],... % 上方居中
            'AwarenessDistance', 1000,... % 最大感知範圍
            'Health', 5000,... % 更高血量
            'Attack', 1000,... % 更強攻擊
            'AttackRange', 100,... % 更大攻擊範圍
            'AttackCooldown', 0,...
            'Graphic', []...
        );
        
        % 創建 BOSS 圖形（不同顏色和大小）
        newBoss.Graphic = rectangle(obj.GameAxes,...
            'Position', [0 0 60 60],... % 更大尺寸
            'FaceColor', [1 0 1],... % 洋紅色
            'Curvature', 0.3); % 圓角矩形
        
        % 加入敵人陣列
        if isempty(obj.Enemies)
            obj.Enemies = newBoss;
        else
            obj.Enemies(end+1) = newBoss;
        end
        
        % 更新標記
        obj.BossAdded = true;
        fprintf('BOSS 已登場！\n'); % 調試用輸出
        updatePosition(newBoss.Graphic, newBoss.Position);
    end
end
