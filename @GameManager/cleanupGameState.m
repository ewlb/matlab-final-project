function cleanupGameState(obj)
    % 重置遊戲狀態
    obj.isPaused = false;
    
    % 清理遊戲對象
    if ~isempty(obj.Bullets)
        for i = 1:length(obj.Bullets)
            if isfield(obj.Bullets(i), 'Graphic') && isvalid(obj.Bullets(i).Graphic)
                delete(obj.Bullets(i).Graphic);
            end
        end
        obj.Bullets = struct('Position', {}, 'Velocity', {}, 'Speed', {}, 'Graphic', {});
    end
    
    % 清理玩家資訊標籤
    try
        if ~isempty(obj.HealthLabel) && isvalid(obj.HealthLabel)
            delete(obj.HealthLabel);
        end
    catch
        % 忽略錯誤
    end
    obj.HealthLabel = [];

    try
        if ~isempty(obj.AttackLabel) && isvalid(obj.AttackLabel)
            delete(obj.AttackLabel);
        end
    catch
        % 忽略錯誤
    end
    obj.AttackLabel = [];

    % 清理計時器
    try
        if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
            stop(obj.GameTimer);
            delete(obj.GameTimer);
        end
    catch
    end
    obj.GameTimer = [];
    
    % 清理時間標籤
    try 
        if ~isempty(obj.TimeLabel) && isvalid(obj.TimeLabel)
            delete(obj.TimeLabel);
        end
    catch

    end
    obj.TimeLabel = [];
    
    % 清理敵人與玩家
    if ~isempty(obj.Enemies)
        for i = 1:length(obj.Enemies)
            if isfield(obj.Enemies(i), 'Graphic') && isvalid(obj.Enemies(i).Graphic)
                delete(obj.Enemies(i).Graphic);
            end
        end
    end
    obj.Enemies = struct();
    
    if isfield(obj, 'Player') && ~isempty(obj.Player) && isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
        delete(obj.Player.Graphic);
    end
    obj.Player = [];
end