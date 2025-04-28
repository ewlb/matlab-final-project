function fireBullet(obj, startPos, direction)
    % 子彈速度
    bulletSpeed = 15;
    
    % 確保保持圖形
    hold(obj.GameAxes, 'on');
    
    % 創建子彈圖形（黑色圓形）
    bulletGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'ko', ...
        'MarkerSize', 8, 'MarkerFaceColor', 'k');
    
    % 新建子彈資料結構
    newBullet = struct(...
        'Position', startPos, ...
        'Velocity', direction * bulletSpeed, ...
        'Speed', bulletSpeed, ...
        'Graphic', bulletGraphic);
    
    % 加入到子彈陣列
    if isempty(obj.Bullets)
        obj.Bullets = newBullet;
    else
        obj.Bullets(end+1) = newBullet;
    end
end