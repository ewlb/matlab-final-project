% 遊戲控制與輸入處理
function handleKeyPress(obj, event)
% 暫停切換
if strcmp(event.Key, 'p')
    currentState = obj.MainFig.WindowState;
    obj.togglePause();
    obj.MainFig.WindowState = currentState;
    return;
end

% 遊戲進行中才處理移動
if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
    speed = 10;
    originalPos = obj.Player.Position;
    newPos = originalPos;

    switch event.Key
        case 'w', newPos(2) = min(obj.gameHeight-30, originalPos(2)+speed);
        case 's', newPos(2) = max(30, originalPos(2)-speed);
        case 'a', newPos(1) = max(30, originalPos(1)-speed);
        case 'd', newPos(1) = min(obj.gameWidth-30, originalPos(1)+speed);
    end

    % 檢查新位置是否有碰撞
    canMove = true;

    % 必須確保敵人數組存在並有內容
    if isfield(obj, 'Enemies') && ~isempty(obj.Enemies)
        for i = 1:length(obj.Enemies)
            % 必須確保每個敵人都有Position字段
            if isfield(obj.Enemies(i), 'Position')
                if obj.checkAABBCollision(newPos, obj.Player.Size, obj.Enemies(i).Position, 30)
                    canMove = false;
                    break;
                end
            end
        end
    end

    % 只有在不碰撞時才移動
    if canMove
        obj.Player.Position = newPos;
    end

    % 更新玩家圖形
    if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
        updatePosition(obj.Player.Graphic, obj.Player.Position);
    end
end
end
