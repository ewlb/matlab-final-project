function resolveEnemyCollisions(obj)
% 若怪物數量小於2，則不需檢查碰撞
if length(obj.Enemies) < 2
    return;
end

% 檢查每對怪物
for i = 1:length(obj.Enemies)-1
    for j = i+1:length(obj.Enemies)
        % 檢查碰撞
        if obj.checkAABBCollision(obj.Enemies(i).Position, 30, ...
                obj.Enemies(j).Position, 30)
            % 計算從怪物j到怪物i的方向向量
            direction = obj.Enemies(i).Position - obj.Enemies(j).Position;

            % 標準化方向向量
            if norm(direction) > 0
                direction = direction / norm(direction);
            else
                % 如果在同一點，隨機推開
                angle = rand() * 2 * pi;
                direction = [cos(angle), sin(angle)];
            end

            % 增加分離距離
            separation = 5.0; % 增加至5.0（原為2.0）

            % 分離兩個敵人
            obj.Enemies(i).Position = obj.Enemies(i).Position + direction * separation;
            obj.Enemies(j).Position = obj.Enemies(j).Position - direction * separation;

            % 更新圖形位置
            updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
            updatePosition(obj.Enemies(j).Graphic, obj.Enemies(j).Position);
        end
    end
end
end