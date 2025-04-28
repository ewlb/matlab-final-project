function updateEnemies(obj)
    % 若無敵人則跳過
    if isempty(obj.Enemies)
        return;
    end

    % 處理每個敵人
    for i = 1:length(obj.Enemies)
        % 確保敵人圖形有效
        if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
            continue;
        end

        % 計算朝向玩家的方向向量
        directionToPlayer = obj.Player.Position - obj.Enemies(i).Position;

        % 計算到玩家的距離
        distanceToPlayer = norm(directionToPlayer);


         % 處理敵人攻擊冷卻
        if obj.Enemies(i).AttackCooldown > 0
            obj.Enemies(i).AttackCooldown = obj.Enemies(i).AttackCooldown - 1;
        end

        % 檢查是否在攻擊範圍內且冷卻結束
        if distanceToPlayer <= obj.Enemies(i).AttackRange && obj.Enemies(i).AttackCooldown <= 0
            % 執行攻擊
            obj.Player.Health = obj.Player.Health - obj.Enemies(i).Attack;
            
            % 設置攻擊冷卻（約2秒，取決於FPS）
            obj.Enemies(i).AttackCooldown = 120;
            
            % 視覺效果 - 閃爍敵人顏色表示攻擊
            originalColor = obj.Enemies(i).Graphic.FaceColor;
            obj.Enemies(i).Graphic.FaceColor = [1 1 0]; % 黃色閃爍
            pause(0.05);
            obj.Enemies(i).Graphic.FaceColor = originalColor;
            
            % 檢查玩家是否死亡
            if obj.Player.Health <= 0
                obj.showGameOverScreen();
                return;
            end
        end


        % 僅在感知範圍內追蹤玩家
        if distanceToPlayer <= obj.Enemies(i).AwarenessDistance
            % 標準化方向向量
            if distanceToPlayer > 0
                normalizedDirection = directionToPlayer / distanceToPlayer;
            else
                normalizedDirection = [0, 0];
            end

            % 設定移動速度
            switch obj.Enemies(i).Type
                case 'melee'
                    moveSpeed = 2;
                case 'ranged'
                    moveSpeed = 1;
                otherwise
                    moveSpeed = 1.5;
            end

            % 保存原始位置
            originalPos = obj.Enemies(i).Position;

            % 計算潛在的新位置
            newPos = originalPos + normalizedDirection * moveSpeed;

            % 檢查是否會與玩家碰撞
            willCollideWithPlayer = obj.checkAABBCollision(newPos, 30, obj.Player.Position, obj.Player.Size);

            % 檢查是否會與其他敵人碰撞
            willCollideWithEnemy = false;
            for j = 1:length(obj.Enemies)
                if i ~= j && obj.checkAABBCollision(newPos, 30, obj.Enemies(j).Position, 30)
                    willCollideWithEnemy = true;
                    break;
                end
            end

            % 只有在沒有碰撞時才移動
            if ~willCollideWithPlayer && ~willCollideWithEnemy
                obj.Enemies(i).Position = newPos;
            end

            % 更新敵人圖形位置
            updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
        end
    end
end