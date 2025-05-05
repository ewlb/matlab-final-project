function updateTimer(obj)
    % % 檢查
    % if ~isvalid(obj.TimeLabel)
    %     return;
    % end
    
    % 更新計時
    obj.ElapsedTime = obj.ElapsedTime + 1;
    minutes = floor(obj.ElapsedTime / 60);
    seconds = mod(obj.ElapsedTime, 60);
    
    % 格式化顯示
    obj.TimeStr = sprintf('%02d:%02d', minutes, seconds);
    
    % 更新UI（確保在主線程執行）
    if isvalid(obj.TimeLabel)
        obj.TimeLabel.Text = ['時間: ' obj.TimeStr];
    end
end
