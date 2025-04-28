function updateBullets(obj)
    % 若無子彈則跳過
    if isempty(obj.Bullets)
        return;
    end
    
    % 用於標記要刪除的子彈
    bulletsToRemove = false(1, length(obj.Bullets));
    
    % 遍歷所有子彈
    for i = 1:length(obj.Bullets)
        % 檢查子彈圖形是否有效，如不是則標記刪除
        if ~isfield(obj.Bullets(i), 'Graphic') || ~isvalid(obj.Bullets(i).Graphic)
            bulletsToRemove(i) = true;
            continue;
        end
        
        % 更新子彈位置
        obj.Bullets(i).Position = obj.Bullets(i).Position + obj.Bullets(i).Velocity;
        
        % 更新圖形位置
        try
            obj.Bullets(i).Graphic.XData = obj.Bullets(i).Position(1);
            obj.Bullets(i).Graphic.YData = obj.Bullets(i).Position(2);
        catch
            % 圖形更新失敗，標記刪除
            bulletsToRemove(i) = true;
            continue;
        end
        
        % 檢查是否超出畫布範圍
        if obj.Bullets(i).Position(1) < obj.AxesXLim(1) || ...
                obj.Bullets(i).Position(1) > obj.AxesXLim(2) || ...
                obj.Bullets(i).Position(2) < obj.AxesYLim(1) || ...
                obj.Bullets(i).Position(2) > obj.AxesYLim(2)
            bulletsToRemove(i) = true;
        end
    end
    
    % 刪除無效或超出範圍的子彈
    obj.removeBullets(bulletsToRemove);
end
