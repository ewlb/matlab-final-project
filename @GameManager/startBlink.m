function startBlink(obj)
    % 停止現有計時器
    if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
        stop(obj.BlinkTimer);
        delete(obj.BlinkTimer);
    end
    
    % 創建新計時器
    obj.BlinkTimer = timer(...
        'ExecutionMode', 'fixedRate',...
        'Period', 0.5,...
        'TasksToExecute', 6,... % 閃爍3秒
        'TimerFcn', @(src,event) obj.toggleBlink());
    
    start(obj.BlinkTimer);
end

function toggleBlink(obj)
    if isvalid(obj.BossWarningGraphic)
        currentAlpha = obj.BossWarningGraphic.FaceColor(4);
        newAlpha = 0.5 + (0.5 - currentAlpha); % 在0.3和0.7之間切換
        obj.BossWarningGraphic.FaceColor(4) = newAlpha;
    end
end