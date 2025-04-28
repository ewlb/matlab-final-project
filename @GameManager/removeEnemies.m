function removeEnemies(obj, indices)
    % 若沒有要刪除的敵人，直接返回
    if ~any(indices)
        return;
    end

    % 刪除圖形對象
    for i = find(indices)
        delete(obj.Enemies(i).Graphic);
    end

    % 從陣列中刪除
    obj.Enemies(indices) = [];
end
