function initBOSS(obj)
% 創建 BOSS 數據結構
newBoss = struct( ...
    'Type', 'boss', ...
    'Position', [obj.gameWidth / 2, obj.gameHeight - 100], ...
    'AwarenessDistance', 114514, ... % not used but hove to add or have error: 
    'Health', 100, ...
    'Attack', 100, ...
    'AttackRange', 114514, ...       % Subscripted assignment between dissimilar structures
    'AttackCooldown', 0, ...
    'Graphic', [] ...
    );

% 創建 BOSS 圖形（不同顏色和大小）
newBoss.Graphic = rectangle(obj.GameAxes, ...
    'Position', [0, 0, 60, 60], ... % 更大尺寸
    'FaceColor', [1, 0, 1], ... % 洋紅色
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
