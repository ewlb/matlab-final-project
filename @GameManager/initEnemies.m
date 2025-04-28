function initEnemies(obj, levelNum)
    obj.Enemies = struct();
    
    switch levelNum
        case 1
            % 近戰敵人配置
            for i = 1:3
                obj.Enemies(i).Type = 'melee';
                obj.Enemies(i).Position = [randi([50 750]), 550];
                obj.Enemies(i).AwarenessDistance = 300;
                obj.Enemies(i).Health = 1314;
                obj.Enemies(i).Attack = 520;
                obj.Enemies(i).AttackRange = 50;
                obj.Enemies(i).AttackCooldown = 0;
                obj.Enemies(i).Graphic = rectangle(obj.GameAxes,...
                    'Position',[0 0 30 30], 'FaceColor','r');
                updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
            end
    end
end