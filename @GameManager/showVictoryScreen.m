function showVictoryScreen(obj)
    % 停止遊戲循環
    if ~isempty(obj.Timer) && isvalid(obj.Timer)
        stop(obj.Timer);
    end
    if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
        stop(obj.GameTimer);
    end
    
    % 隱藏其他面板
    obj.CurrentPanel.Visible = 'off';
    
    % 顯示勝利畫面
    obj.VictoryPanel.Visible = 'on';
    obj.CurrentPanel = obj.VictoryPanel;
    
    % 強制更新畫面
    drawnow;
end
