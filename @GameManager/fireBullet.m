% 修改後 fireBullet.m
function fireBullet(obj, startPos, direction, isBossBullet, attackerAttack)
    
    if isBossBullet
        markerSize = 12;
        color = [1 0 0]; % 紅色
        bulletSpeed = 15;
    else
        markerSize = 8;
        color = [0 0 0]; % 黑色
        bulletSpeed = 15;
    end

    % 創建子彈圖形
    bulletGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o',...
        'MarkerSize', markerSize,...
        'MarkerFaceColor', color,...
        'MarkerEdgeColor', color);

    % 子彈資料結構
    newBullet = struct(...
        'Position', startPos,...
        'Velocity', direction * bulletSpeed,...
        'Damage', attackerAttack,...       
        'IsBossBullet', isBossBullet,...
        'Graphic', bulletGraphic);

    % 加入子彈陣列
    if isempty(obj.Bullets)
        obj.Bullets = newBullet;
    else
        obj.Bullets(end+1) = newBullet;
    end
end
