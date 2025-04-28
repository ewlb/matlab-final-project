% 更新位置輔助函數
function updatePosition(graphicObj, pos)
    try
        if ~isvalid(graphicObj)
            warning('嘗試更新無效的圖形對象');

            return;
        end

        % 取得目前的寬高
        rectPos = graphicObj.Position;
        width = rectPos(3);
        height = rectPos(4);

        % 設定新位置
        graphicObj.Position = [pos(1)-width/2, pos(2)-height/2, width, height];
    catch
        % 忽略錯誤，防止崩潰
    end
end