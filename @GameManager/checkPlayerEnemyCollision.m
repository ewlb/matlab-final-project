function checkPlayerEnemyCollision(obj)
% 檢查玩家與敵人碰撞
if isempty(obj.Enemies)
    return;
end

% 檢查每個敵人
for i = 1:length(obj.Enemies)
    if obj.checkAABBCollision(obj.Player.Position, obj.Player.Size, ...
            obj.Enemies(i).Position, 30)
        % 計算從敵人到玩家的方向向量
        direction = obj.Player.Position - obj.Enemies(i).Position;

        % 標準化方向向量
        if norm(direction) > 0
            direction = direction / norm(direction);
        else
            direction = [0, 1]; % 預設方向
        end

        % 計算所需的最小分離距離
        minDistance = (obj.Player.Size + 30)/2 + 2; % 半尺寸和加上緩衝

        % 計算目前距離
        currentDistance = norm(obj.Player.Position - obj.Enemies(i).Position);

        % 計算需要推開的距離
        pushDistance = minDistance - currentDistance;

        % 只有需要分離時才移動
        if pushDistance > 0
            obj.Player.Position = obj.Player.Position + direction * pushDistance;
            updatePosition(obj.Player.Graphic, obj.Player.Position);
        end

        return; % 處理完一個碰撞後返回
    end
end
end