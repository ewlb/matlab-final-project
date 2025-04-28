function checkBulletCollisions(obj)
    % 無子彈或敵人則跳過
    if isempty(obj.Bullets) || isempty(obj.Enemies)
        return;
    end

    % 標記要刪除的子彈
    bulletsToRemove = false(1, length(obj.Bullets));
    % 標記要刪除的敵人
    enemiesToRemove = false(1, length(obj.Enemies));

    % 檢查每顆子彈與每個敵人是否碰撞
    for b = 1:length(obj.Bullets)
        % 確保子彈圖形有效
        if ~isfield(obj.Bullets(b), 'Graphic') || ~isvalid(obj.Bullets(b).Graphic)
            bulletsToRemove(b) = true;
            continue;
        end
        
        for e = 1:length(obj.Enemies)
            % 確保敵人圖形有效
            if ~isfield(obj.Enemies(e), 'Graphic') || ~isvalid(obj.Enemies(e).Graphic)
                continue;
            end
            
            % 計算距離
            dist = norm(obj.Bullets(b).Position - obj.Enemies(e).Position);

            % 若距離小於敵人半徑，判定為碰撞
            if dist < 15
                bulletsToRemove(b) = true;
                
                % 減少敵人血量
                obj.Enemies(e).Health = obj.Enemies(e).Health - obj.Player.Attack;
                
                % 檢查敵人血量是否小於等於0
                if obj.Enemies(e).Health <= 0
                    enemiesToRemove(e) = true;
                end
                
                break;  % 一顆子彈只碰撞一次
            end
        end
    end

    % 刪除碰撞的子彈
    obj.removeBullets(bulletsToRemove);
    
    % 刪除死亡的敵人
    obj.removeEnemies(enemiesToRemove);
end
