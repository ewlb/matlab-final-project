classdef final_all < handle
    properties
        MainFig % 主視窗
        MainPanel % 主選單面板
        LevelPanel % 關卡選擇面板
        GamePanel % 遊戲面板
        HelpPanel % 說明面板
        PausePanel % 暫停面板
        GameOverPanel % 遊戲結束面板
        VictoryPanel

        CurrentPanel % 當前顯示的面板
        GameState = 'MAIN_MENU' % 遊戲狀態追蹤
        % 可能值: MAIN_MENU, LEVEL_SELECT, PLAYING, PAUSED, GAME_OVER, HELP

        % 螢幕尺寸
        ScreenWidth
        ScreenHeight
        gameWidth = 1000
        gameHeight = 700

        LevelUnlocked = [true, false, false]; % 第1關預設可點擊，其餘預設鎖定
        LevelButtons % 用來儲存 uibutton 物件的 handle
        LevelsCleared = [false, false, false];

        % 遊戲核心元素
        GameAxes
        Player
        Enemies = struct()
        Bullets = struct('Position', {}, 'Velocity', {}, 'Damage', {}, ...
            'IsBossBullet', {}, 'Graphic', {}, 'AnimationFrame', {}, ...
            'FrameCount', {}, 'AnimationTimer', {}, 'AnimationSpeed', {}, ...
            'Angle', {}, 'Size', {}, 'ImageSize', {}, 'IsImageBullet', {})

        Timer
        MousePos = [0, 0]

        % 玩家資訊標籤
        HealthLabel
        AttackLabel

        % 遊戲設定
        isPaused = false
        AxesXLim
        AxesYLim
        CurrentLevel

        TimeLabel % 時間顯示標籤
        GameTimer % 遊戲計時器
        ElapsedTime = 0 % 累計時間(秒)
        TimeStr = '00:00' % 時間顯示字串

        BossAdded = false
        BossWarningGraphic = [] % 預警標記圖形物件
        BossWarningActive = false % 預警狀態標記
        BlinkTimer = [] % 閃爍效果計時器

        BossAppearTimes = [16, 13, 10]

        FireballFrames = {} % Store the fireball animation frames

        % basePath dynamically
        basePath = fileparts(mfilename('fullpath'));
        % basePath = 'C:\Users\User\Desktop\matlab_\final';

        % player animation property
        IdleFrames
        RunFrames
        CurrentDirection = 3 % 1=上，2=左，3=下，4=右
        IsMoving = false
        CurrentFrame = 1
        AnimationTimer = 0
        AnimationSpeed = 0.1
        % used to fix input latency
        KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false)

        % 技能(1)
        SkillCooldown = 0 % 技能冷卻時間(秒)
        SkillMaxCooldown = 3 % 最大冷卻時間
        SkillLabel % 技能冷卻顯示標籤
        SkillEffects = {} % 存儲技能動畫效果
        SkillDescLabel % 技能說明標籤
        SkillIcon % 技能圖標
        Skill1Frames = {} % 技能1動畫幀
        Skill1Animations = {} % 技能1動畫實例
        % 0604_02.1新增：技能1本關已用次數 & 最大可用次數
        Skill1UseCount = 0
        Skill1MaxUses = 6

        % 技能2
        Skill2Cooldown = 0
        Skill2MaxCooldown = 5
        Skill2Label
        Skill2DescLabel
        Skill2Icon
        PoisonProjectiles = {}
        PoisonAreas = {}
        % 0604_02.2新增：技能2本關已用次數 & 最大可用次數
        Skill2UseCount = 0
        Skill2MaxUses = 4


        % 技能3
        Skill3Cooldown = 0
        Skill3MaxCooldown = 8
        Skill3Label
        Skill3DescLabel
        Skill3Icon
        ExplosionFrames = {}
        Skill3Animation = []
        % 0604_02.3新增：技能3本關已用次數 & 最大可用次數
        Skill3UseCount = 0
        Skill3MaxUses = 2

        % 敵人生成
        EnemySpawnTimer = 0 % 生成計時器
        EnemySpawnInterval = 5 % 生成間隔(秒)
        MaxEnemies = 8 % 最大敵人數量
        SpawnMargin = 50 % 在畫面邊緣外的生成邊距

        BossHealthBars %0606

        HeadRunFrames
        HeadGraphic

        PlayerBulletFrames = {} % 預旋轉的玩家子彈圖片
        NumBulletAngles = 120
        BulletAngleStep = 360 / 120

        VictorySound
        VictorySoundPath

        BGMPlayer % 用來播放背景音樂的 audioplayer 物件
        HitSEPlayer % 用來播放玩家受擊音效的 audioplayer 物件

        BossPoisonProjectiles = {} % BOSS毒藥水投擲物
        BossPoisonAreas = {} % BOSS毒區域

        BossExplosionEffect = [] % BOSS大爆炸動畫效果
        BossExplosionWarning = [] % BOSS大爆炸警告
        BossExplosionTimer = 0 % BOSS大爆炸倒數計時
        BossExplosionActive = false % BOSS大爆炸是否啟動
        BossExplosionScheduled = false % BOSS是否已安排爆炸
        BossExplosionTime = 20 % BOSS爆炸時間（遊戲時間20秒）
        Boss3ExplosionWarning = [] % 全螢幕警告圖形
        Boss3WarningActive = false % 警告是否啟動

        enemiessize = 10;

        EnemyRunFrames = {} % 敵人跑步動畫幀
        EnemyAnimationTimer = 0 % 敵人動畫計時器
        EnemyAnimationSpeed = 0.15 % 敵人動畫速度

        EnemyAttackFrames = {} % 敵人攻擊動畫幀
        EnemyAttackAnimationSpeed = 0.1 % 攻擊動畫速度
        EnemyHurtFrames = {}

    end

    methods
        function obj = final_all()
            % 創建唯一的主視窗並設置背景
            obj.MainFig = uifigure('Name', '痛扁叫獸');
            obj.MainFig.WindowState = 'fullscreen';
            obj.MainFig.Color = [0.1, 0.1, 0.4];

            % 取得螢幕大小
            screenSize = get(0, 'ScreenSize');
            obj.ScreenWidth = screenSize(3);
            obj.ScreenHeight = screenSize(4);

            % 預加載所有面板
            obj.MainPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'on', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.LevelPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.HelpPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.VictoryPanel = uipanel(obj.MainFig, 'Position', [0, 0, obj.ScreenWidth, obj.ScreenHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]); % 綠色背景

            % 計算位置
            xOffset = (obj.ScreenWidth - obj.gameWidth) / 2;
            yOffset = (obj.ScreenHeight - obj.gameHeight) / 2;

            % 遊戲相關面板
            obj.GamePanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0.1, 0.1, 0.4]);
            obj.PausePanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0, 0, 0, 0.5]);
            obj.GameOverPanel = uipanel(obj.MainFig, 'Position', [xOffset, yOffset, obj.gameWidth, obj.gameHeight], 'Visible', 'off', 'BackgroundColor', [0, 0, 0, 0.8]);

            % 初始化所有面板內容
            obj.initMainMenu();
            obj.initLevelSelect();
            obj.initHelpScreen();
            obj.initPauseMenu();
            obj.initGameOverScreen();
            obj.initVictoryScreen();

            % 設置當前面板
            obj.CurrentPanel = obj.MainPanel;

            % 設置窗口關閉時的清理函數
            obj.MainFig.CloseRequestFcn = @(src, event) obj.cleanup();

            obj.loadVictorySound();

            % ========================================================
            % 載入背景音樂 (BGM)
            % ========================================================
            try
                % 假設你把音檔放在 <basePath>/sound/bgm.mp3
                bgmPath = fullfile(obj.basePath, 'sound', 'bgm.mp3');
                [y_bgm, Fs_bgm] = audioread(bgmPath);
                % 如果覺得音量太大，可適度縮放:
                y_bgm = y_bgm * 0.1;

                obj.BGMPlayer = audioplayer(y_bgm, Fs_bgm);
                % 當音樂播放完，StopFcn 就會自動重播
                set(obj.BGMPlayer, 'StopFcn', @(~, ~) play(obj.BGMPlayer));
                % 一開始就播放背景音樂 (非阻塞)
                play(obj.BGMPlayer);
            catch ME
                %warning('無法載入或播放背景音樂：%s', ME.message);
                %obj.BGMPlayer = [];
            end

            % ========================================================
            % 載入玩家受擊音效 (Hit SE)
            % ========================================================
            try
                % 假設你把音效檔放在 <basePath>/sound/hit.mp3
                hitPath = fullfile(obj.basePath, 'sound', 'hit.mp3');
                [y_hit, Fs_hit] = audioread(hitPath);
                obj.HitSEPlayer = audioplayer(y_hit, Fs_hit);
            catch ME
                %warning('無法載入玩家受擊音效：%s', E.message);
                %obj.HitSEPlayer = [];
            end

        end

        function cleanup(obj)
            % 停止並刪除定時器
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                try
                    stop(obj.Timer);
                    delete(obj.Timer);
                catch
                    % 忽略錯誤
                end
            end

            % 清理遊戲資源
            obj.cleanupGameState();

            % ------------------------------------------------
            % 修改：先把 StopFcn 清空，再停止 BGM
            % ------------------------------------------------
            if ~isempty(obj.BGMPlayer)
                try
                    set(obj.BGMPlayer, 'StopFcn', []); % 先移除循環播放的回呼
                    stop(obj.BGMPlayer);
                catch
                    % 忽略錯誤
                end
            end

            % 如果勝利音效還在播放，也一併停止
            if ~isempty(obj.VictorySound)
                try
                    set(obj.VictorySound, 'StopFcn', []);
                    stop(obj.VictorySound);
                catch
                    % 忽略錯誤
                end
            end

            % 關閉視窗
            delete(obj.MainFig);
        end


        % 狀態管理核心函數
        function switchPanel(obj, panelName)

            % 共通的狀態轉換處理
            obj.handleStateTransition(obj.GameState, panelName);

            % 隱藏當前面板
            obj.CurrentPanel.Visible = 'off';

            % 顯示目標面板
            switch panelName
                case 'main'
                    obj.cleanupGameState();
                    obj.CurrentPanel = obj.MainPanel;
                    obj.GameState = 'MAIN_MENU';
                case 'level'
                    obj.CurrentPanel = obj.LevelPanel;
                    obj.GameState = 'LEVEL_SELECT';
                case 'game'
                    obj.CurrentPanel = obj.GamePanel;
                    obj.GameState = 'PLAYING';
                case 'pause'
                    obj.CurrentPanel = obj.PausePanel;
                    obj.GameState = 'PAUSED';
                case 'gameover'
                    obj.CurrentPanel = obj.GameOverPanel;
                    obj.GameState = 'GAME_OVER';
                case 'help'
                    obj.CurrentPanel = obj.HelpPanel;
                    obj.GameState = 'HELP';
            end

            % 確保新面板有效
            if isvalid(obj.CurrentPanel)
                obj.CurrentPanel.Visible = 'on';
                drawnow;
            end
        end

        % 狀態轉換處理
        function handleStateTransition(obj, fromState, toPanel)

            % 從遊戲中轉移到其他面板
            if strcmp(fromState, 'PLAYING') && ~strcmp(toPanel, 'game') && ~strcmp(toPanel, 'pause') && ~strcmp(toPanel, 'gameover')
                % 離開遊戲時，停止計時器並清理資源
                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    try
                        stop(obj.Timer);
                        delete(obj.Timer);
                    catch
                        % 忽略錯誤
                    end
                    obj.Timer = [];
                end
                obj.cleanupGameState();
            end

            % 從暫停狀態轉移
            if strcmp(toPanel, 'game')
                % 從暫停返回遊戲，重啟計時器
                if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                    start(obj.Timer);
                end
            end
            % 從遊戲結束狀態轉移
            if strcmp(fromState, 'GAME_OVER')
                % 離開遊戲結束畫面時，確保徹底清理
                fprintf('test')
                obj.isPaused = false;
            end
        end


        % 遊戲關卡控制
        function startLevel(obj, levelNum)
            % 重置遊戲狀態
            obj.GameState = 'PLAYING';
            obj.CurrentLevel = levelNum;
            obj.isPaused = false;

            % 確保舊的遊戲元素被清理
            obj.cleanupGameState();
            % 0604_02.4：先把本關三個技能的使用次數歸零
            obj.Skill1UseCount = 0;
            obj.Skill2UseCount = 0;
            obj.Skill3UseCount = 0;
            % 初始化遊戲畫面
            obj.initGameScreen(levelNum);

            % 技能次數重置0605
            obj.Skill1UseCount = 0;
            obj.Skill2UseCount = 0;
            obj.Skill3UseCount = 0;

            % 技能啟用控制0605
            % 技能1啟用：破完第1關（不包含當前是第1關未破完）
            if obj.LevelsCleared(1)
                obj.SkillLabel.Visible = 'on';
                obj.SkillIcon.Visible = 'on';
                obj.SkillDescLabel.Visible = 'on';
            end

            % 技能2啟用：破完第2關才開
            if obj.LevelsCleared(2)
                obj.Skill2Label.Visible = 'on';
                obj.Skill2Icon.Visible = 'on';
                obj.Skill2DescLabel.Visible = 'on';
            end

            % 技能3啟用：破完第3關才開
            if obj.LevelsCleared(3)
                obj.Skill3Label.Visible = 'on';
                obj.Skill3Icon.Visible = 'on';
                obj.Skill3DescLabel.Visible = 'on';
            end
            obj.switchPanel('game');
            % 重置計時器狀態
            obj.ElapsedTime = 0;
            obj.TimeStr = '00:00';
            obj.TimeLabel.Text = obj.TimeStr;

            % 創建遊戲計時器（與現有遊戲循環計時器分離）
            obj.GameTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1, ...
                'TimerFcn', @(src, event) obj.updateTimer(), ...
                'BusyMode', 'drop');
            start(obj.GameTimer);
        end

        % 暫停功能
        function togglePause(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')

                obj.isPaused = true;

                % 重置所有按鍵
                obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
                obj.IsMoving = false;

                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                end
                obj.switchPanel('pause');

            elseif obj.isPaused && strcmp(obj.GameState, 'PAUSED')
                % 恢復遊戲
                obj.isPaused = false;
                obj.switchPanel('game');
                if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(get(obj.Timer, 'Running'), 'off')
                    start(obj.Timer); % 只有計時器未運行時才啟動
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    start(obj.GameTimer);
                end
            end
        end


        function quitGame(obj)
            obj.cleanup();
        end

        function trackMousePosition(obj)
            % 只在遊戲面板可見時更新滑鼠位置
            if strcmp(obj.GameState, 'PLAYING') && isvalid(obj.GameAxes)
                cp = obj.GameAxes.CurrentPoint;
                obj.MousePos = cp(1, 1:2);
            end
        end

        function handleMouseClick(obj)
            % 只處理左鍵點擊且遊戲未暫停時
            if strcmp(obj.GameState, 'PLAYING') && ~obj.isPaused && strcmp(obj.MainFig.SelectionType, 'normal')
                % 計算發射方向
                direction = obj.MousePos - obj.Player.Position;

                % 標準化方向向量
                if norm(direction) > 0
                    direction = direction / norm(direction);

                    % 創建並發射子彈
                    obj.fireBullet(obj.Player.Position, direction, false, obj.Player.Attack);
                end
            end
        end

        function gameLoop(obj)
            try
                % 只在遊戲狀態且非暫停時執行
                if strcmp(obj.GameState, 'PLAYING') && ~obj.isPaused
                    % 檢查玩家圖形是否有效
                    if ~isfield(obj.Player, 'Graphic') || ~isvalid(obj.Player.Graphic)
                        % 重建玩家圖形
                        obj.Player.Graphic = rectangle(obj.GameAxes, 'Position', [0, 0, 30, 30], ...
                            'FaceColor', 'b');
                        updatePosition(obj.Player.Graphic, obj.Player.Position);
                    end

                    % 檢查敵人圖形是否有效
                    for i = 1:length(obj.Enemies)
                        % 跳過標記為刪除的敵人
                        if isfield(obj.Enemies(i), 'MarkedForDeletion') && obj.Enemies(i).MarkedForDeletion
                            continue;
                        end
                        % TODO
                        if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
                            % 根據敵人類型重建圖形
                            if strcmp(obj.Enemies(i).Type, 'boss')
                                % 特殊處理BOSS圖形
                                obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                                    'Position', [0, 0, 60, 60], ... % 更大尺寸
                                    'FaceColor', [1, 0, 1], ... % 洋紅色
                                    'Curvature', 0.3); % 圓角矩形
                            else
                                % 普通敵人圖形
                                obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                                    'Position', [0, 0, 30, 30], ...
                                    'FaceColor', 'r');
                            end
                            updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                        end
                    end

                    % 更新遊戲邏輯
                    obj.updatePlayerMovement();
                    obj.updateBullets();
                    obj.checkBulletCollisions();
                    obj.updateEnemies();
                    obj.resolveEnemyCollisions();
                    obj.checkPlayerEnemyCollision();
                    obj.updatePlayerAnimation(0.016);

                    obj.updateSkillSystem(0.016);
                    obj.updateSkillUI();
                    % skill_2
                    obj.updatePoisonProjectiles(0.016);
                    obj.updatePoisonAreas(0.016);
                    obj.updateSkill2UI();

                    % skill_3
                    obj.updateSkill3Animation(0.016);
                    obj.updateSkill3UI();


                    % 敵人生成
                    obj.updateEnemySpawning(0.016);

                    % boss skill
                    obj.updateBossPoisonProjectiles(0.016);
                    obj.updateBossPoisonAreas(0.016);

                    % 更新玩家資訊顯示
                    if isvalid(obj.HealthLabel)
                        obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
                    end
                    if isvalid(obj.AttackLabel)
                        obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
                    end

                    % 檢查玩家是否死亡
                    if obj.Player.Health <= 0
                        fprintf('Player died! Health: %d\n', obj.Player.Health); % 添加調試輸出
                        obj.showGameOverScreen();
                        return;
                    end
                    drawnow limitrate;
                end
            catch ME
                disp(['遊戲循環錯誤: ', ME.message]);
                disp(getReport(ME));
            end
        end

        function updatePlayerMovement(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                speed = 5;
                % 處理玩家減速效果
                if isfield(obj.Player, 'SlowTimer') && obj.Player.SlowTimer > 0
                    obj.Player.SlowTimer = obj.Player.SlowTimer - 0.016;
                    if obj.Player.SlowTimer <= 0
                        obj.Player.PoisonSlowed = false;
                    end
                end

                % 如果被BOSS毒減速，速度減半
                if isfield(obj.Player, 'PoisonSlowed') && obj.Player.PoisonSlowed
                    speed = speed * 0.5;
                end
                originalPos = obj.Player.Position;
                newPos = originalPos;
                moved = false;

                % 根據按鍵狀態更新位置
                if obj.KeysPressed.w
                    newPos(2) = min(obj.gameHeight-30, originalPos(2)+speed);
                    moved = true;
                end
                if obj.KeysPressed.s
                    newPos(2) = max(30, originalPos(2)-speed);
                    moved = true;
                end
                if obj.KeysPressed.a
                    newPos(1) = max(30, originalPos(1)-speed);
                    moved = true;
                end
                if obj.KeysPressed.d
                    newPos(1) = min(obj.gameWidth-30, originalPos(1)+speed);
                    moved = true;
                end

                % 只有在實際移動時才更新IsMoving狀態
                obj.IsMoving = moved;

                % 檢查碰撞
                if moved
                    canMove = true;

                    % 敵人碰撞檢測...
                    if isfield(obj, 'Enemies') && ~isempty(obj.Enemies)
                        for i = 1:length(obj.Enemies)
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
                        obj.updatePlayerPosition();
                    end
                end
            end
        end

        function updatePlayerAnimation(obj, deltaTime)
            % 更新動畫計時器
            obj.AnimationTimer = obj.AnimationTimer + deltaTime;

            % 時間到達後切換幀
            if obj.AnimationTimer >= obj.AnimationSpeed
                obj.AnimationTimer = 0;

                if obj.IsMoving
                    % 運行動畫 - 循環切換8幀
                    totalFrames = 8;
                    obj.CurrentFrame = mod(obj.CurrentFrame, totalFrames) + 1;

                    % 更新身體動畫
                    if ~isempty(obj.RunFrames)
                        bodyFrame = obj.RunFrames{obj.CurrentDirection, obj.CurrentFrame};
                        if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                            obj.Player.Graphic.CData = bodyFrame.Image;
                            obj.Player.Graphic.AlphaData = bodyFrame.Alpha;
                        end
                    end

                    % 更新頭部動畫
                    if ~isempty(obj.HeadRunFrames) && isvalid(obj.HeadGraphic)
                        headFrame = obj.HeadRunFrames{obj.CurrentDirection, obj.CurrentFrame};
                        obj.HeadGraphic.CData = headFrame.Image;
                        obj.HeadGraphic.AlphaData = headFrame.Alpha;
                    end

                else
                    % 靜止動畫 - 身體使用idle，頭部使用第一幀
                    if ~isempty(obj.IdleFrames)
                        bodyFrame = obj.IdleFrames{obj.CurrentDirection};
                        if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                            obj.Player.Graphic.CData = bodyFrame.Image;
                            obj.Player.Graphic.AlphaData = bodyFrame.Alpha;
                        end
                    end

                    % 頭部靜止時使用跑步動畫的第一幀
                    if ~isempty(obj.HeadRunFrames) && isvalid(obj.HeadGraphic)
                        headFrame = obj.HeadRunFrames{obj.CurrentDirection, 1};
                        obj.HeadGraphic.CData = headFrame.Image;
                        obj.HeadGraphic.AlphaData = headFrame.Alpha;
                    end
                end
            end
        end


        % 顯示遊戲結束畫面
        function showGameOverScreen(obj)
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                obj.isPaused = true;

                % 重置按鍵狀態
                obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
                obj.IsMoving = false;

                if ~isempty(obj.Timer) && isvalid(obj.Timer)
                    stop(obj.Timer);
                end
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                end
                obj.switchPanel('gameover');
            end
        end


        function retry(obj)

            obj.startLevel(obj.CurrentLevel);
            % delete(obj.Timer);
            % obj.Timer = [];

        end

        % 碰撞檢測
        function collision = checkCollision(obj, pos1, size1, pos2, size2, type1, type2)
            % 通用碰撞檢測函數
            % type: 'circle' 或 'rectangle'
            if nargin < 7
                type2 = 'circle'; % 預設為圓形
            end
            if nargin < 6
                type1 = 'circle'; % 預設為圓形
            end

            if strcmp(type1, 'circle') && strcmp(type2, 'circle')
                % 圓形與圓形碰撞檢測
                radius1 = size1 / 2;
                radius2 = size2 / 2;
                distance = norm(pos1-pos2);
                collision = distance < (radius1 + radius2);
            elseif strcmp(type1, 'rectangle') || strcmp(type2, 'rectangle')
                % 包含矩形的碰撞檢測（保持原有AABB邏輯）
                halfSize1 = size1 / 2;
                halfSize2 = size2 / 2;
                collision = abs(pos1(1)-pos2(1)) < (halfSize1 + halfSize2) && ...
                    abs(pos1(2)-pos2(2)) < (halfSize1 + halfSize2);
            else
                collision = false;
            end
        end

        % 保留舊函數名稱的兼容性包裝
        function collision = checkAABBCollision(obj, pos1, size1, pos2, size2)
            collision = obj.checkCollision(pos1, size1, pos2, size2, 'circle', 'circle');
        end


        function startBlink(obj)
            % 停止現有計時器
            if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
                stop(obj.BlinkTimer);
                delete(obj.BlinkTimer);
            end

            % 創建新計時器
            obj.BlinkTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TasksToExecute', 6, ... % 閃爍3秒=6*0.5
                'TimerFcn', @(src, event) obj.toggleBlink());

            start(obj.BlinkTimer);
        end

        function toggleBlink(obj)
            if isvalid(obj.BossWarningGraphic)
                if (obj.BossWarningGraphic.FaceAlpha < 0.5)
                    obj.BossWarningGraphic.FaceAlpha = 0.8;
                else
                    obj.BossWarningGraphic.FaceAlpha = 0.4;
                end
            end
        end

        function initMainMenu(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            % 遊戲標題
            titleLbl = uilabel(obj.MainPanel);
            titleLbl.Text = '痛扁叫獸';
            titleLbl.FontSize = 48;
            titleLbl.FontColor = 'w';
            titleLbl.Position = [centerX - 200, centerY + 150, 400, 60];

            % 遊戲開始按鈕
            startBtn = uibutton(obj.MainPanel, 'push');
            startBtn.Text = '開始遊戲';
            startBtn.Position = [centerX - 100, centerY, 200, 60];
            startBtn.FontSize = 24;
            startBtn.BackgroundColor = [0.2, 0.6, 1];
            startBtn.FontColor = 'w';
            startBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('level');

            % 遊戲說明按鈕
            helpBtn = uibutton(obj.MainPanel, 'push');
            helpBtn.Text = '遊戲說明';
            helpBtn.Position = [centerX - 100, centerY - 100, 200, 60];
            helpBtn.FontSize = 24;
            helpBtn.BackgroundColor = [0.2, 0.6, 1];
            helpBtn.FontColor = 'w';
            helpBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('help');
        end
        function initHelpScreen(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            % 說明標題
            titleLbl = uilabel(obj.HelpPanel);
            titleLbl.Text = '遊戲說明';
            titleLbl.FontSize = 36;
            titleLbl.FontColor = 'w';
            titleLbl.Position = [centerX - 100, centerY + 200, 200, 40];

            % 基本操作說明
            basicControlLbl = uilabel(obj.HelpPanel);
            basicControlLbl.Text = '基本操作';
            basicControlLbl.FontSize = 24;
            basicControlLbl.FontColor = [1, 1, 0]; % 黃色標題
            basicControlLbl.Position = [centerX - 200, centerY + 150, 150, 30];

            % 基本操作內容
            instructLbl = uilabel(obj.HelpPanel);
            instructLbl.Text = sprintf('%s\n%s\n%s', '移動: WASD鍵', '射擊: 滑鼠左鍵', '暫停: P鍵');
            instructLbl.WordWrap = 'on';
            instructLbl.FontSize = 18;
            instructLbl.FontColor = 'w';
            instructLbl.Position = [centerX - 200, centerY + 80, 400, 80];

            % 技能說明標題
            skillTitleLbl = uilabel(obj.HelpPanel);
            skillTitleLbl.Text = '技能系統';
            skillTitleLbl.FontSize = 24;
            skillTitleLbl.FontColor = [1, 1, 0]; % 黃色標題
            skillTitleLbl.Position = [centerX - 200, centerY + 30, 150, 30];

            % 技能1說明
            skill1Lbl = uilabel(obj.HelpPanel);
            skill1Lbl.Text = '技能1 (按鍵1): 範圍傷害';
            skill1Lbl.FontSize = 16;
            skill1Lbl.FontColor = [0.8, 1, 0.8]; % 淺綠色
            skill1Lbl.Position = [centerX - 200, centerY - 10, 400, 25];

            skill1DetailLbl = uilabel(obj.HelpPanel);
            skill1DetailLbl.Text = '在鼠標位置造成1.5倍攻擊力的範圍傷害，冷卻3秒';
            skill1DetailLbl.FontSize = 14;
            skill1DetailLbl.FontColor = 'w';
            skill1DetailLbl.Position = [centerX - 180, centerY - 35, 400, 20];

            % 技能2說明
            skill2Lbl = uilabel(obj.HelpPanel);
            skill2Lbl.Text = '技能2 (按鍵2): 毒藥水';
            skill2Lbl.FontSize = 16;
            skill2Lbl.FontColor = [0.8, 1, 0.8]; % 淺綠色
            skill2Lbl.Position = [centerX - 200, centerY - 65, 400, 25];

            skill2DetailLbl = uilabel(obj.HelpPanel);
            skill2DetailLbl.Text = '投擲毒藥水，在目標位置生成持續傷害區域並減速敵人，冷卻4秒';
            skill2DetailLbl.FontSize = 14;
            skill2DetailLbl.FontColor = 'w';
            skill2DetailLbl.Position = [centerX - 180, centerY - 90, 400, 20];

            % 技能3說明
            skill3Lbl = uilabel(obj.HelpPanel);
            skill3Lbl.Text = '技能3 (按鍵3): 超級大爆炸';
            skill3Lbl.FontSize = 16;
            skill3Lbl.FontColor = [1, 0.5, 0.5]; % 淺紅色 - 表示終極技能
            skill3Lbl.Position = [centerX - 200, centerY - 120, 400, 25];

            skill3DetailLbl = uilabel(obj.HelpPanel);
            skill3DetailLbl.Text = '消滅畫面上所有敵人的終極技能，冷卻3秒';
            skill3DetailLbl.FontSize = 14;
            skill3DetailLbl.FontColor = 'w';
            skill3DetailLbl.Position = [centerX - 180, centerY - 145, 400, 20];

            % 遊戲提示
            tipTitleLbl = uilabel(obj.HelpPanel);
            tipTitleLbl.Text = '遊戲提示';
            tipTitleLbl.FontSize = 20;
            tipTitleLbl.FontColor = [1, 1, 0]; % 黃色標題
            tipTitleLbl.Position = [centerX - 200, centerY - 185, 150, 30];

            tipLbl = uilabel(obj.HelpPanel);
            tipLbl.Text = sprintf('%s\n%s\n', ...
                '• 滑鼠在不同位置點擊可以射很快', '• 擊敗BOSS就贏');
            tipLbl.WordWrap = 'on';
            tipLbl.FontSize = 14;
            tipLbl.FontColor = 'w';
            tipLbl.Position = [centerX - 180, centerY - 250, 400, 60];

            % 返回按鈕
            backBtn = uibutton(obj.HelpPanel, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Position = [centerX - 100, centerY - 300, 200, 50];
            backBtn.FontSize = 18;
            backBtn.BackgroundColor = [0.8, 0.2, 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('main');
        end
        %% 關卡選擇
        function initLevelSelect(obj)
            % -------------------------------------------------------------------
            % 先建立「主網格」，以便後續將按鈕等元件放進去
            % -------------------------------------------------------------------
            mainGrid = uigridlayout(obj.LevelPanel, [3, 1]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.BackgroundColor = [0.1, 0.1, 0.4];

            % 標題區域
            titleLbl = uilabel(mainGrid);
            titleLbl.Text = '選擇關卡';
            titleLbl.FontSize = 36;
            titleLbl.FontColor = 'w';
            titleLbl.HorizontalAlignment = 'center';
            titleLbl.Layout.Row = 1;
            titleLbl.Layout.Column = 1;

            % -------------------------------------------------------------------
            % 在 mainGrid 的第二列建立一個三欄的子網格（btnGrid）放關卡按鈕
            % -------------------------------------------------------------------
            btnGrid = uigridlayout(mainGrid, [1, 3]);
            btnGrid.Padding = [50, 0, 50, 0];
            btnGrid.Layout.Row = 2;
            btnGrid.Layout.Column = 1;
            btnGrid.BackgroundColor = [0.1, 0.1, 0.4];

            % 建立並存下三個關卡按鈕
            obj.LevelButtons = gobjects(1, 3);
            for i = 1:3
                btn = uibutton(btnGrid, 'push');
                btn.Text = sprintf('第 %d 關', i);
                btn.FontSize = 24;
                btn.BackgroundColor = [0.3, 0.7, 0.5];
                btn.FontColor = 'w';
                btn.ButtonPushedFcn = @(src, event) obj.startLevel(i);
                % 根據 LevelUnlocked 決定是否可用
                if ~obj.LevelUnlocked(i)
                    btn.Enable = 'off';
                end
                obj.LevelButtons(i) = btn; % 存下按鈕物件
            end

            % -------------------------------------------------------------------
            % 最後在 mainGrid 的第三列放「返回主畫面」按鈕
            % -------------------------------------------------------------------
            backGrid = uigridlayout(mainGrid, [1, 3]);
            backGrid.Padding = [0, 100, 0, 100];
            backGrid.BackgroundColor = [0.1, 0.1, 0.4];
            backGrid.Layout.Row = 3;
            backGrid.Layout.Column = 1;

            backBtn = uibutton(backGrid, 'push');
            backBtn.Text = '返回主畫面';
            backBtn.Layout.Column = 2; % 置中
            backBtn.FontSize = 30;
            backBtn.BackgroundColor = [0.8, 0.2, 0.2];
            backBtn.FontColor = 'w';
            backBtn.ButtonPushedFcn = @(src, event) obj.switchPanel('main');
        end


        function initGameScreen(obj, levelNum)
            % 清理舊的遊戲元素
            obj.cleanupGameState();
            delete(findobj(obj.GamePanel, 'Type', 'UIAxes'));

            % 創建遊戲畫布
            obj.GameAxes = uiaxes(obj.GamePanel);
            obj.GameAxes.Position = [0, 0, obj.gameWidth, obj.gameHeight];

            % 更新遊戲限制範圍
            obj.AxesXLim = [0, obj.gameWidth];
            obj.AxesYLim = [0, obj.gameHeight];

            % 設定固定顯示範圍
            axis(obj.GameAxes, 'equal');
            xlim(obj.GameAxes, obj.AxesXLim);
            ylim(obj.GameAxes, obj.AxesYLim);
            hold(obj.GameAxes, 'on');
            set(obj.GameAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');

            % 禁用默認交互
            disableDefaultInteractivity(obj.GameAxes);
            obj.GameAxes.Interactions = [];
            obj.GameAxes.Toolbar = [];

            % 暫停按鈕
            pauseBtn = uibutton(obj.GamePanel, 'push');
            pauseBtn.Text = '⏸';
            pauseBtn.Position = [obj.gameWidth - 70, obj.gameHeight - 50, 40, 40];
            pauseBtn.FontSize = 24;
            pauseBtn.BackgroundColor = [0.9, 0.9, 0.9];
            pauseBtn.ButtonPushedFcn = @(src, event) obj.togglePause();

            % 設置控制監聽
            set(obj.MainFig, 'KeyPressFcn', @(src, event) obj.handleKeyPress(event));
            set(obj.MainFig, 'KeyReleaseFcn', @(src, event) obj.handleKeyRelease(event));
            set(obj.MainFig, 'WindowButtonMotionFcn', @(src, event) obj.trackMousePosition());
            set(obj.MainFig, 'WindowButtonDownFcn', @(src, event) obj.handleMouseClick());

            % 初始化遊戲元素
            obj.initPlayer();
            obj.initEnemies(levelNum);
            % 根據關卡調整生成參數
            switch levelNum
                case 1
                    obj.EnemySpawnInterval = 4;
                    obj.MaxEnemies = 10;
                case 2
                    obj.EnemySpawnInterval = 3;
                    obj.MaxEnemies = 15;
                case 3
                    obj.EnemySpawnInterval = 2;
                    obj.MaxEnemies = 20;
            end

            % 重置生成計時器
            obj.EnemySpawnTimer = 0;

            % 添加時間標籤
            obj.TimeLabel = uilabel(obj.MainFig);
            obj.TimeLabel.Text = '時間: 00:00';
            obj.TimeLabel.Position = [50, obj.ScreenHeight - 50, 200, 30];
            obj.TimeLabel.FontSize = 18;
            obj.TimeLabel.FontColor = 'w';
            obj.TimeLabel.BackgroundColor = [0.1, 0.1, 0.4];


            % 創建玩家標籤
            obj.HealthLabel = uilabel(obj.MainFig);
            obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
            obj.HealthLabel.Position = [50, obj.ScreenHeight - 100, 200, 30];
            obj.HealthLabel.FontSize = 18;
            obj.HealthLabel.FontColor = 'w';
            obj.HealthLabel.BackgroundColor = [0.1, 0.1, 0.4];

            obj.AttackLabel = uilabel(obj.MainFig);
            obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
            obj.AttackLabel.Position = [50, obj.ScreenHeight - 150, 200, 30];
            obj.AttackLabel.FontSize = 18;
            obj.AttackLabel.FontColor = 'w';
            obj.AttackLabel.BackgroundColor = [0.1, 0.1, 0.4];

            % skill_1
            obj.SkillIcon = uiimage(obj.MainFig);
            imagePath = fullfile(obj.basePath, 'images', 'skill', 'mikunani.png');
            obj.SkillIcon.ImageSource = imagePath;
            obj.SkillIcon.Position = [65, obj.ScreenHeight - 200, 30, 30]; % 調整大小和位置
            obj.SkillIcon.Visible = 'off'; % 初始隱藏

            obj.SkillLabel = uilabel(obj.MainFig);
            obj.SkillLabel.Text = '';
            obj.SkillLabel.Position = [50, obj.ScreenHeight - 200, 80, 40];
            obj.SkillLabel.FontSize = 18;
            obj.SkillLabel.FontColor = 'w';
            obj.SkillLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.SkillLabel.HorizontalAlignment = 'center';
            obj.SkillLabel.Visible = 'off';


            obj.SkillDescLabel = uilabel(obj.MainFig);
            obj.SkillDescLabel.Text = '技能(1)';
            obj.SkillDescLabel.Position = [135, obj.ScreenHeight - 200, 100, 40];
            obj.SkillDescLabel.FontSize = 14;
            obj.SkillDescLabel.FontColor = 'w';
            obj.SkillDescLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.loadSkill1Frames();
            obj.SkillDescLabel.Visible = 'off';


            % 技能2
            obj.Skill2Icon = uiimage(obj.MainFig);
            imagePath = fullfile(obj.basePath, 'images', 'skill', 'mikunani.png');
            obj.Skill2Icon.ImageSource = imagePath;
            obj.Skill2Icon.Position = [65, obj.ScreenHeight - 250, 30, 30];
            obj.Skill2Icon.Visible = 'off';

            obj.Skill2Label = uilabel(obj.MainFig);
            obj.Skill2Label.Text = '';
            obj.Skill2Label.Position = [50, obj.ScreenHeight - 250, 80, 40];
            obj.Skill2Label.FontSize = 18;
            obj.Skill2Label.FontColor = 'w';
            obj.Skill2Label.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill2Label.HorizontalAlignment = 'center';
            obj.Skill2Label.Visible = 'off';

            obj.Skill2DescLabel = uilabel(obj.MainFig);
            obj.Skill2DescLabel.Text = '技能(2)';
            obj.Skill2DescLabel.Position = [135, obj.ScreenHeight - 250, 100, 40];
            obj.Skill2DescLabel.FontSize = 14;
            obj.Skill2DescLabel.FontColor = 'w';
            obj.Skill2DescLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill2DescLabel.Visible = 'off';

            % skill3
            % 第三個技能 - 添加在第二個技能下方
            obj.Skill3Icon = uiimage(obj.MainFig);
            imagePath = fullfile(obj.basePath, 'images', 'skill', 'mikunani.png');
            obj.Skill3Icon.ImageSource = imagePath;
            obj.Skill3Icon.Position = [65, obj.ScreenHeight - 300, 30, 30];
            obj.Skill3Icon.Visible = 'off';

            obj.Skill3Label = uilabel(obj.MainFig);
            obj.Skill3Label.Text = '';
            obj.Skill3Label.Position = [50, obj.ScreenHeight - 300, 80, 40];
            obj.Skill3Label.FontSize = 18;
            obj.Skill3Label.FontColor = 'w';
            obj.Skill3Label.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill3Label.HorizontalAlignment = 'center';
            obj.Skill3Label.Visible = 'off';

            obj.Skill3DescLabel = uilabel(obj.MainFig);
            obj.Skill3DescLabel.Text = '技能(3)';
            obj.Skill3DescLabel.Position = [135, obj.ScreenHeight - 300, 100, 40];
            obj.Skill3DescLabel.FontSize = 14;
            obj.Skill3DescLabel.FontColor = 'w';
            obj.Skill3DescLabel.BackgroundColor = [0.1, 0.1, 0.4];
            obj.Skill3DescLabel.Visible = 'off';
            % 載入爆炸動畫幀
            obj.loadExplosionFrames();

            obj.FireballFrames = cell(1, 5);
            obj.loadPlayerBulletFrames();

            for i = 1:5
                try
                    % Load fireball image
                    % 構建完整的圖片路徑
                    imagePath = fullfile(obj.basePath, 'images', 'FB00', sprintf('FB00%d.png', i));

                    [img, map, alpha] = imread(imagePath);
                    img = ind2rgb(img, map); % 轉換為雙精度，保持色彩一致性
                    obj.FireballFrames{i} = struct('Image', img, 'Alpha', alpha);
                catch e
                    warning('Failed to load fireball image %d: %s', i, e.message);
                    % Create a fallback orange circle as fireball
                    img = ones(30, 30, 3, 'uint8');
                    img(:, :, 1) = 255; % Red
                    img(:, :, 2) = 165; % Green (make orange)
                    img(:, :, 3) = 0; % Blue
                    obj.FireballFrames{i} = struct('Image', img, 'Alpha', []);
                end
            end

            % 確保計時器處於運行狀態
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                obj.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.016, ...
                    'TimerFcn', @(src, event) obj.gameLoop());
            end

            if strcmp(get(obj.Timer, 'Running'), 'off')
                start(obj.Timer);
            end
        end
        % 初始化暫停選單（新增）
        function initPauseMenu(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            menuContainer = uipanel(obj.PausePanel, ...
                'Position', [(obj.gameWidth - 300) / 2, (obj.gameHeight - 300) / 2, 300, 300], ...
                'BackgroundColor', [0.3, 0.3, 0.3]);

            % 暫停標籤
            uilabel(menuContainer, ...
                'Text', '遊戲已暫停', ...
                'Position', [50, 250, 200, 40], ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 繼續按鈕
            resumeBtn = uibutton(menuContainer, 'push', ...
                'Text', '繼續遊戲', ...
                'Position', [50, 200, 200, 60], ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.togglePause(), ...
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(menuContainer, 'push', ...
                'Text', '返回主畫面', ...
                'Position', [50, 110, 200, 60], ...
                'BackgroundColor', [0.2, 0.2, 0.6], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(menuContainer, 'push', ...
                'Text', '離開遊戲', ...
                'Position', [50, 20, 200, 60], ...
                'BackgroundColor', [0.6, 0.2, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                btnStyle{:});
        end
        %  modify from initpausemenu
        function initGameOverScreen(obj)
            % 半透明背景面板已在構造函數中建立

            % 暫停選單容器
            gameOverContainer = uipanel(obj.GameOverPanel, ...
                'Position', [(obj.gameWidth - 300) / 2, (obj.gameHeight - 300) / 2, 300, 300], ...
                'BackgroundColor', [0.3, 0.3, 0.3]);

            % 暫停標籤
            uilabel(gameOverContainer, ...
                'Text', 'YOU ARE SO DEAD', ...
                'Position', [0, 250, 300, 40], ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'HorizontalAlignment', 'center');

            % 按鈕樣式
            btnStyle = {'FontSize', 18, 'FontColor', 'w', 'FontWeight', 'bold'};

            % 重新按鈕
            retryBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '重玩', ...
                'Position', [50, 200, 200, 60], ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.retry(), ...
                btnStyle{:});

            % 主選單按鈕
            mainMenuBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '返回主畫面', ...
                'Position', [50, 110, 200, 60], ...
                'BackgroundColor', [0.2, 0.2, 0.6], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 離開遊戲按鈕
            quitBtn = uibutton(gameOverContainer, 'push', ...
                'Text', '離開遊戲', ...
                'Position', [50, 20, 200, 60], ...
                'BackgroundColor', [0.6, 0.2, 0.2], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                btnStyle{:});
        end
        function initVictoryScreen(obj)
            % 計算中央位置
            centerX = obj.ScreenWidth / 2;
            centerY = obj.ScreenHeight / 2;

            vicLbl = uilabel(obj.VictoryPanel);
            vicLbl.Text = 'victory!!!';
            vicLbl.FontSize = 48;
            vicLbl.FontColor = 'w';
            vicLbl.Position = [centerX - 100, centerY + 150, 200, 100];
            vicLbl.HorizontalAlignment = 'center'; % maybe unnecessary

            % 按鈕基礎樣式
            btnStyle = {; ...
                'FontSize', 24, ...
                'BackgroundColor', [0.2, 0.6, 1], ... % 主畫面按鈕藍色
                'FontColor', 'w'};

            % 選擇關卡按鈕
            levelBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '選擇關卡', ...
                'Position', [centerX - 100, centerY, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('level'), ...
                btnStyle{:});

            % 返回主畫面按鈕
            mainBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '主畫面', ...
                'Position', [centerX - 100, centerY - 100, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.switchPanel('main'), ...
                btnStyle{:});

            % 退出遊戲按鈕(紅色突出)
            quitBtn = uibutton(obj.VictoryPanel, 'push', ...
                'Text', '退出遊戲', ...
                'Position', [centerX - 100, centerY - 200, 200, 60], ...
                'ButtonPushedFcn', @(src, event) obj.quitGame(), ...
                'FontSize', 24, ...
                'FontColor', 'w', ...
                'BackgroundColor', [0.8, 0.2, 0.2]); % 紅色
        end
        function initPlayer(obj)
            % 玩家角色初始化
            obj.Player = struct( ...
                'Position', [400, 50], ...
                'Size', 30, ...
                'Health', 10, ...
                'Attack', 1, ...
                'Graphic', [], ...
                'PoisonSlowed', false, ...
                'SlowTimer', 0 ...
                );
            obj.loadPlayerAnimations();

            if ~isempty(obj.IdleFrames)
                initialFrame = obj.IdleFrames{3}; % 向下idle
                width = 60; % 跟 updatePlayerPosition 一起改
                height = 60;
                obj.Player.Graphic = image(obj.GameAxes, ...
                    'CData', initialFrame.Image, ...
                    'AlphaData', initialFrame.Alpha, ...
                    'XData', [obj.Player.Position(1) - width / 2, obj.Player.Position(1) + width / 2], ...
                    'YData', [obj.Player.Position(2) - height / 2, obj.Player.Position(2) + height / 2]);
            else
                % 備用方案 - 藍色矩形
                obj.Player.Graphic = rectangle(obj.GameAxes, 'Position', [0, 0, 30, 30], ...
                    'FaceColor', 'b');
            end
            % 初始化頭部圖形
            if ~isempty(obj.HeadRunFrames)
                % 使用第一幀作為初始頭部
                initialHeadFrame = obj.HeadRunFrames{3, 1}; % 向下第一幀
                headWidth = 60; % 與身體相同大小
                headHeight = 60;

                obj.HeadGraphic = image(obj.GameAxes, ...
                    'CData', initialHeadFrame.Image, ...
                    'AlphaData', initialHeadFrame.Alpha, ...
                    'XData', [obj.Player.Position(1) - headWidth / 2, obj.Player.Position(1) + headWidth / 2], ...
                    'YData', [obj.Player.Position(2) - headHeight / 2, obj.Player.Position(2) + headHeight / 2]);
            end
            % 重置玩家狀態
            obj.CurrentDirection = 3; % 預設向下
            obj.IsMoving = false;
            obj.CurrentFrame = 1;
            obj.AnimationTimer = 0;

            % 重置按鍵狀態
            obj.KeysPressed = struct('w', false, 'a', false, 's', false, 'd', false);
            % 更新位置
            obj.updatePlayerPosition();
        end

        function updatePlayerPosition(obj)
            if isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                if isa(obj.Player.Graphic, 'matlab.graphics.primitive.Image')
                    % 是 image 的話，用 XData/YData 更新
                    width = 60;
                    height = 60;
                    obj.Player.Graphic.XData = [obj.Player.Position(1) - width / 2, obj.Player.Position(1) + width / 2];
                    obj.Player.Graphic.YData = [obj.Player.Position(2) - height / 2, obj.Player.Position(2) + height / 2];

                    % 頭部也更新
                    if ~isempty(obj.HeadGraphic) && isvalid(obj.HeadGraphic)
                        headWidth = 60;
                        headHeight = 60;
                        obj.HeadGraphic.XData = [obj.Player.Position(1) - headWidth / 2, obj.Player.Position(1) + headWidth / 2];
                        obj.HeadGraphic.YData = [obj.Player.Position(2) - headHeight / 2, obj.Player.Position(2) + headHeight / 2];
                    end
                elseif isa(obj.Player.Graphic, 'matlab.graphics.primitive.Rectangle')
                    % 是 rectangle 的話，用 Position 更新
                    obj.Player.Graphic.Position = [obj.Player.Position(1) - 15, obj.Player.Position(2) - 15, 30, 30];
                end
            end
        end

        function initEnemies(obj, levelNum)
            obj.loadEnemyAnimations();
            obj.loadEnemyAttackAnimations();
            obj.loadEnemyHurtAnimations();

            obj.Enemies = struct('Type', {}, 'Position', {}, ...
                'Health', {}, 'Attack', {}, 'AttackRange', {}, ...
                'AttackCooldown', {}, 'SkillCooldown', {}, ...
                'SkillMaxCooldown', {}, 'SkillWarning', {}, ...
                'SkillWarningTimer', {}, 'PoisonSlowed', {}, ...
                'SlowTimer', {}, 'Graphic', {}, 'MarkedForDeletion', {}, ...
                'Direction', {}, 'AnimationFrame', {}, 'AnimationTimer', {}, ...
                'IsMoving', {}, 'IsAttacking', {}, 'AttackAnimationFrame', {}, ...
                'AttackAnimationTimer', {}, 'AttackDirection', {}, 'HasDamaged', {}, ...
                'IsHurt', {}, 'HurtTimer', {}, 'OriginalDirection', {}, ...
                'OriginalAlpha', {}, 'OriginalColor', {}, 'IsFlashing', {}, 'FlashTimer', {});

            % switch levelNum
            %     case 1
            %         % 近戰敵人配置（如果需要）
            %         for i = 1:3
            %             newEnemy = struct( ...
            %                 'Type', 'melee', ...
            %                 'Position', [randi([50, 750]), 550], ...
            %                 'Health', 10, ...
            %                 'Attack', 1, ...
            %                 'AttackRange', 80, ...
            %                 'AttackCooldown', 0, ...
            %                 'SkillCooldown', 0, ...
            %                 'SkillMaxCooldown', 0, ...
            %                 'SkillWarning', [], ...
            %                 'SkillWarningTimer', 0, ...
            %                 'PoisonSlowed', false, ...
            %                 'SlowTimer', 0, ...
            %                 'Graphic', [], ...
            %                 'MarkedForDeletion', false, ...
            %                 'Direction', 1, ...
            %                 'AnimationFrame', 1, ...
            %                 'AnimationTimer', 0, ...
            %                 'IsMoving', false, ...
            %                 'IsAttacking', false, ...
            %                 'AttackAnimationFrame', 1, ...
            %                 'AttackAnimationTimer', 0, ...
            %                 'AttackDirection', 1, ...
            %                 'HasDamaged', false, ...
            %                 'IsHurt', false, ...
            %                 'HurtTimer', 0, ...
            %                 'OriginalDirection', 1, ...
            %                 'OriginalAlpha', [], ...
            %                 'OriginalColor', [], ...
            %                 'IsFlashing', false, ...
            %                 'FlashTimer', [] ...
            %                 );
            % 
            %             % 創建敵人圖形
            %             newEnemy.Graphic = obj.createEnemyGraphic(newEnemy.Position, i);
            % 
            %             % 保存原始透明度或顏色
            %             if isa(newEnemy.Graphic, 'matlab.graphics.primitive.Image')
            %                 originalAlpha = get(newEnemy.Graphic, 'AlphaData');
            %                 if isempty(originalAlpha)
            %                     originalAlpha = ones(size(get(newEnemy.Graphic, 'CData'), 1), size(get(newEnemy.Graphic, 'CData'), 2));
            %                 end
            %                 newEnemy.OriginalAlpha = originalAlpha;
            %             elseif isa(newEnemy.Graphic, 'matlab.graphics.primitive.Rectangle')
            %                 newEnemy.OriginalColor = newEnemy.Graphic.FaceColor;
            %             end
            % 
            %             obj.Enemies(i) = newEnemy;
            %         end
            % end
        end

        function enemyGraphic = createEnemyGraphic(obj, position, enemyIndex)
            % 創建敵人圖形（使用動畫或圓形備用）
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            if ~isempty(obj.EnemyRunFrames)
                % 使用動畫圖片
                initialFrame = obj.EnemyRunFrames{1, 1}; % 向下第一幀
                [h, w, ~] = size(initialFrame.Image);

                % 設定敵人大小
                enemySize = 80; % 可調整大小
                scaleFactor = enemySize / max(h, w);
                displayW = w * scaleFactor;
                displayH = h * scaleFactor;

                enemyGraphic = image(obj.GameAxes, ...
                    'CData', initialFrame.Image, ...
                    'AlphaData', initialFrame.Alpha, ...
                    'XData', [position(1) - displayW / 2, position(1) + displayW / 2], ...
                    'YData', [position(2) - displayH / 2, position(2) + displayH / 2]);
            else
                % 備用：使用圓形
                enemyGraphic = plot(obj.GameAxes, position(1), position(2), 'o', ...
                    'MarkerSize', obj.enemiessize*2, ...
                    'MarkerFaceColor', 'r', ...
                    'MarkerEdgeColor', 'r', ...
                    'LineWidth', 2);
            end

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function initBOSS(obj)
            % ==== 1. 動態決定 boss 圖檔名稱 ====
            level = obj.CurrentLevel; % 1、2 或 3
            imgName = sprintf('boss%d.jpg', level);
            imgPath = fullfile(obj.basePath, 'images', 'boss', imgName);

            if exist(imgPath, 'file') == 2
                bossImg = imread(imgPath);
                bossImg = flipud(bossImg); % 上下翻轉，修正顛倒問題
                [h0, w0, ~] = size(bossImg);
                % 計算要顯示的尺寸（保留比例）
                targetSize = 100; % 可自行調整
                scaleFactor = targetSize / max(h0, w0);
                displayW = round(w0*scaleFactor);
                displayH = round(h0*scaleFactor);
            else
                warning('找不到 BOSS 圖片：%s，改用矩形顯示', imgPath);
                bossImg = [];
                displayW = 60;
                displayH = 60;
            end

            % ==== 2. BOSS 出現位置（取畫面頂端下方一點） ====
            bossCenter = [obj.gameWidth / 2, obj.gameHeight - 100];

            % ==== 3. 建立 newBoss 結構 ====
            newBoss = struct( ...
                'Type', 'boss', ...
                'Position', bossCenter, ...
                'Health', 40, ...
                'Attack', 2, ...
                'AttackRange', 114514, ...
                'AttackCooldown', 0, ...
                'SkillCooldown', 0, ...
                'SkillMaxCooldown', 2, ...
                'SkillWarning', [], ...
                'SkillWarningTimer', 0, ...
                'PoisonSlowed', false, ...
                'SlowTimer', 0, ...
                'Graphic', [], ...
                'MarkedForDeletion', false, ...
                'Direction', 1, ...
                'AnimationFrame', 1, ...
                'AnimationTimer', 0, ...
                'IsMoving', false, ...
                'IsAttacking', false, ...
                'AttackAnimationFrame', 1, ...
                'AttackAnimationTimer', 0, ...
                'AttackDirection', 1, ...
                'HasDamaged', false, ...
                'IsHurt', false, ...
                'HurtTimer', 0, ...
                'OriginalDirection', 1, ...
                'OriginalAlpha', [], ...
                'OriginalColor', [], ...
                'IsFlashing', false, ...
                'FlashTimer', [] ...
                );


            % ==== 4. 如果 bossImg 不為空就用 image()，否則 fallback 用紫色矩形 ====
            if ~isempty(bossImg)
                xData = [bossCenter(1) - displayW/2, bossCenter(1) + displayW/2];
                yData = [bossCenter(2) - displayH/2, bossCenter(2) + displayH/2];
                hImg = image(obj.GameAxes, xData, yData, bossImg);
            else
                hImg = rectangle(obj.GameAxes, ...
                    'Position', [bossCenter(1)-displayW/2, bossCenter(2)-displayH/2, displayW, displayH], ...
                    'FaceColor', [1, 0, 1], ...
                    'Curvature', 0.3);
            end

            % ==== 5. 把 handle 存回 newBoss.Graphic ====
            newBoss.Graphic = hImg;

            % ==== 新增：保存原始透明度和顏色 ====
            if isa(hImg, 'matlab.graphics.primitive.Image')
                % 保存原始AlphaData
                originalAlpha = get(hImg, 'AlphaData');
                if isempty(originalAlpha)
                    originalAlpha = ones(size(bossImg, 1), size(bossImg, 2));
                end
                newBoss.OriginalAlpha = originalAlpha;
                newBoss.IsFlashing = false;  % 閃爍狀態標記
                newBoss.FlashTimer = [];     % 閃爍計時器
            elseif isa(hImg, 'matlab.graphics.primitive.Rectangle')
                % 保存原始顏色
                newBoss.OriginalColor = hImg.FaceColor;
                newBoss.IsFlashing = false;
                newBoss.FlashTimer = [];
            end
            % ==== 6. 建立血條 ====
            barWidth = 100;
            barHeight = 10;
            offsetY = 70; % 血條在BOSS上方

            % 血條背景
            bg = rectangle(obj.GameAxes, ...
                'Position', [bossCenter(1) - barWidth / 2, bossCenter(2) + offsetY, barWidth, barHeight], ...
                'FaceColor', [0.3, 0.3, 0.3], 'EdgeColor', 'none');

            % 血條前景（紅條）
            fg = rectangle(obj.GameAxes, ...
                'Position', [bossCenter(1) - barWidth / 2, bossCenter(2) + offsetY, barWidth, barHeight], ...
                'FaceColor', [1, 0, 0], 'EdgeColor', 'none');

            % 儲存 handle
            obj.BossHealthBars = struct('BG', bg, 'FG', fg, 'Width', barWidth, 'OffsetY', offsetY);

            % ==== 7. 加到 Enemies 裡 ====
            if isempty(obj.Enemies)
                obj.Enemies = newBoss;
            else
                obj.Enemies(end+1) = newBoss;
            end

            obj.BossAdded = true;
            fprintf('BOSS (關卡 %d) 已登場！\n', level);

            % ==== 8. 確保位置置中 ====
            updatePosition(hImg, bossCenter);
        end


        function handleKeyPress(obj, event)
            % 暫停切換
            if strcmp(event.Key, 'p')
                currentState = obj.MainFig.WindowState;
                obj.togglePause();
                obj.MainFig.WindowState = currentState;
                return;
            end

            % ---- 修改：依照 CurrentLevel 判斷可用技能 ----
            % 只在遊戲中、未暫停、且正在 PLAYING 時才考慮技能按鍵
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')

                switch event.Key
                    case '1'
                        if obj.LevelsCleared(1) % 第1關破過後才可用技能1
                            obj.useSkill();
                        end
                    case '2'
                        if obj.LevelsCleared(2) % 第2關破過後才可用技能2
                            obj.useSkill2();
                        end
                    case '3'
                        if obj.LevelsCleared(3) % 第3關破過後才可用技能3
                            obj.useSkill3();
                        end


                    otherwise
                        % 非技能相關鍵時，才進入移動控制
                        % 等下面再處理 WASD
                end
            end

            % ---- 以下為原本的移動控制邏輯 ----
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                if ismember(event.Key, {'w', 'a', 's', 'd'})
                    obj.KeysPressed.(event.Key) = true;
                    obj.IsMoving = true;
                    switch event.Key
                        case 'w', obj.CurrentDirection = 1; % 上
                        case 'a', obj.CurrentDirection = 2; % 左
                        case 's', obj.CurrentDirection = 3; % 下
                        case 'd', obj.CurrentDirection = 4; % 右
                    end
                end
            end
        end


        function updateBullets(obj)
            % 若無子彈則跳過
            if isempty(obj.Bullets)
                return;
            end

            % 用於標記要刪除的子彈
            bulletsToRemove = false(1, length(obj.Bullets));

            % 遍歷所有子彈
            for i = 1:length(obj.Bullets)
                obj.Bullets(i).Position = obj.Bullets(i).Position + obj.Bullets(i).Velocity;
                if obj.Bullets(i).IsBossBullet && isfield(obj.Bullets(i), 'AnimationFrame')
                    % Update fireball animation
                    try
                        % Get current size
                        w = diff(obj.Bullets(i).Graphic.XData);
                        h = diff(obj.Bullets(i).Graphic.YData);


                        % Update position
                        obj.Bullets(i).Graphic.XData = [obj.Bullets(i).Position(1) - w / 2, obj.Bullets(i).Position(1) + w / 2];
                        obj.Bullets(i).Graphic.YData = [obj.Bullets(i).Position(2) - h / 2, obj.Bullets(i).Position(2) + h / 2];

                        % Update animation frame
                        obj.Bullets(i).AnimationTimer = obj.Bullets(i).AnimationTimer + 0.016; % Assuming 60 FPS
                        if obj.Bullets(i).AnimationTimer >= obj.Bullets(i).AnimationSpeed
                            % Reset timer
                            obj.Bullets(i).AnimationTimer = 0;

                            % Advance frame
                            obj.Bullets(i).AnimationFrame = mod(obj.Bullets(i).AnimationFrame, obj.Bullets(i).FrameCount) + 1;

                            % Get next frame and rotate it
                            frame = obj.FireballFrames{obj.Bullets(i).AnimationFrame};
                            img = frame.Image;
                            alpha = frame.Alpha;

                            % Rotate image for direction
                            % rotatedImg = imrotate(img, -obj.Bullets(i).Angle, 'bicubic');
                            rotatedImg = imrotate(img, -obj.Bullets(i).Angle, 'bicubic');

                            if ~isempty(alpha)
                                rotatedAlpha = imrotate(alpha, -obj.Bullets(i).Angle, 'bicubic');
                                obj.Bullets(i).Graphic.AlphaData = rotatedAlpha;
                            end

                            % Update image
                            obj.Bullets(i).Graphic.CData = rotatedImg;

                            % Recalculate size and position after rotation
                            [h, w, ~] = size(rotatedImg);
                            obj.Bullets(i).Graphic.XData = [obj.Bullets(i).Position(1) - w / 2, obj.Bullets(i).Position(1) + w / 2];
                            obj.Bullets(i).Graphic.YData = [obj.Bullets(i).Position(2) - h / 2, obj.Bullets(i).Position(2) + h / 2];
                        end
                    catch e
                        % Failed to update graphic, mark for removal
                        bulletsToRemove(i) = true;
                        continue;
                    end
                else
                    try
                        obj.Bullets(i).Graphic.XData = [obj.Bullets(i).Position(1) - obj.Bullets(i).ImageSize(1) / 2, ...
                            obj.Bullets(i).Position(1) + obj.Bullets(i).ImageSize(1) / 2];
                        obj.Bullets(i).Graphic.YData = [obj.Bullets(i).Position(2) - obj.Bullets(i).ImageSize(2) / 2, ...
                            obj.Bullets(i).Position(2) + obj.Bullets(i).ImageSize(2) / 2];
                    catch
                        bulletsToRemove(i) = true;
                    end

                end
                if obj.Bullets(i).Position(1) < obj.AxesXLim(1) || ...
                        obj.Bullets(i).Position(1) > obj.AxesXLim(2) || ...
                        obj.Bullets(i).Position(2) < obj.AxesYLim(1) || ...
                        obj.Bullets(i).Position(2) > obj.AxesYLim(2)
                    bulletsToRemove(i) = true;
                end
            end

            obj.removeBullets(bulletsToRemove);
        end

        function updateEnemies(obj)
            % 若無敵人則跳過
            if isempty(obj.Enemies)
                return;
            end

            % 處理每個敵人
            for i = 1:length(obj.Enemies)

                % 跳過標記為刪除的敵人
                if isfield(obj.Enemies(i), 'MarkedForDeletion') && obj.Enemies(i).MarkedForDeletion
                    continue;
                end
                % 確保敵人圖形有效
                % if ~isfield(obj.Enemies(i), 'Graphic') || ~isvalid(obj.Enemies(i).Graphic)
                %     if strcmp(obj.Enemies(i).Type, 'boss')
                %         % BOSS 圖形重建邏輯
                %         level = obj.CurrentLevel;
                %         imgName = sprintf('boss%d.jpg', level);
                %         imgPath = fullfile(obj.basePath, 'images', 'boss', imgName);
                %
                %         if exist(imgPath, 'file') == 2
                %             bossImg = imread(imgPath);
                %             bossImg = flipud(bossImg);
                %             [h0, w0, ~] = size(bossImg);
                %             targetSize = 100;
                %             scaleFactor = targetSize / max(h0, w0);
                %             displayW = round(w0*scaleFactor);
                %             displayH = round(h0*scaleFactor);
                %
                %             xData = [obj.Enemies(i).Position(1) - displayW / 2, obj.Enemies(i).Position(1) + displayW / 2];
                %             yData = [obj.Enemies(i).Position(2) - displayH / 2, obj.Enemies(i).Position(2) + displayH / 2];
                %             obj.Enemies(i).Graphic = image(obj.GameAxes, xData, yData, bossImg);
                %         else
                %             obj.Enemies(i).Graphic = rectangle(obj.GameAxes, ...
                %                 'Position', [obj.Enemies(i).Position(1) - 30, obj.Enemies(i).Position(2) - 30, 60, 60], ...
                %                 'FaceColor', [1, 0, 1], ...
                %                 'Curvature', 0.3);
                %         end
                %     else
                %         % 普通敵人圖形重建
                %         obj.Enemies(i).Graphic = obj.createEnemyGraphic(obj.Enemies(i).Position, i);
                %     end
                %
                %     % 更新位置（確保圖形在正確位置）
                %     obj.updateEnemyPosition(i);
                % end


                % 計算朝向玩家的方向向量
                directionToPlayer = obj.Player.Position - obj.Enemies(i).Position;
                distanceToPlayer = norm(directionToPlayer);
                % 標準化方向向量
                if distanceToPlayer > 0
                    normalizedDirection = directionToPlayer / distanceToPlayer;
                else
                    normalizedDirection = [0, 0];
                end

                if strcmp(obj.Enemies(i).Type, 'boss')
                    % BOSS專用邏輯
                    obj.Enemies(i).AttackCooldown = max(0, obj.Enemies(i).AttackCooldown-0.016);
                    obj.Enemies(i).SkillCooldown = max(0, obj.Enemies(i).SkillCooldown-0.016);

                    % 更新技能警示計時器
                    if obj.Enemies(i).SkillWarningTimer > 0
                        obj.Enemies(i).SkillWarningTimer = obj.Enemies(i).SkillWarningTimer - 0.016;

                        % 閃爍效果
                        if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                            % 創建閃爍效果
                            blinkInterval = 0.2; % 每0.2秒閃爍一次
                            blinkPhase = mod(obj.Enemies(i).SkillWarningTimer, blinkInterval);
                            if blinkPhase < blinkInterval / 2
                                obj.Enemies(i).SkillWarning.FaceAlpha = 0.5;
                            else
                                obj.Enemies(i).SkillWarning.FaceAlpha = 0.1;
                            end
                        end

                        % 警示結束，執行技能傷害
                        if obj.Enemies(i).SkillWarningTimer <= 0
                            % 移除警示圖形
                            if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                                warningCenter = [mean(obj.Enemies(i).SkillWarning.XData), ...
                                    mean(obj.Enemies(i).SkillWarning.YData)];
                                delete(obj.Enemies(i).SkillWarning);
                                obj.Enemies(i).SkillWarning = [];

                                % 執行技能傷害
                                obj.executeBossSkillDamage(i, warningCenter, 60);
                            end
                        end
                    end

                    % 普通攻擊（火球）
                    if obj.Enemies(i).AttackCooldown <= 0
                        obj.fireBullet(obj.Enemies(i).Position, normalizedDirection, true, obj.Enemies(i).Attack);
                        obj.Enemies(i).AttackCooldown = 0.5;
                    end

                    % 技能攻擊邏輯
                    if obj.Enemies(i).SkillCooldown <= 0 && obj.Enemies(i).SkillWarningTimer <= 0
                        obj.useBossSkill(i);
                    end
                else

                    % 處理敵人攻擊冷卻
                    if obj.Enemies(i).AttackCooldown > 0
                        obj.Enemies(i).AttackCooldown = obj.Enemies(i).AttackCooldown - 0.016;
                    end

                    % 檢查是否在攻擊範圍內
                    inAttackRange = distanceToPlayer <= obj.Enemies(i).AttackRange;

                    if inAttackRange && obj.Enemies(i).AttackCooldown <= 0 && ~obj.Enemies(i).IsAttacking
                        % 開始攻擊
                        obj.Enemies(i).IsAttacking = true;
                        obj.Enemies(i).AttackAnimationFrame = 1;
                        obj.Enemies(i).AttackAnimationTimer = 0;
                        obj.Enemies(i).AttackDirection = obj.getEnemyMoveDirection(normalizedDirection);
                        obj.Enemies(i).AttackCooldown = 2.0; % 2秒攻擊冷卻
                        obj.Enemies(i).IsMoving = false;
                        obj.Enemies(i).HasDamaged = false; % 重置傷害標記

                        fprintf('敵人 %d 開始攻擊！\n', i);
                    elseif ~obj.Enemies(i).IsAttacking
                        % 移動邏輯（只有不在攻擊時才移動）
                        obj.Enemies(i).AnimationTimer = obj.Enemies(i).AnimationTimer + 0.016;

                        newDirection = obj.getEnemyMoveDirection(normalizedDirection);
                        if newDirection ~= obj.Enemies(i).Direction
                            obj.Enemies(i).Direction = newDirection;
                            obj.Enemies(i).AnimationFrame = 1;
                            obj.Enemies(i).AnimationTimer = 0;
                        end

                        % 設定移動速度
                        switch obj.Enemies(i).Type
                            case 'melee'
                                moveSpeed = 2;
                            case 'ranged'
                                moveSpeed = 1;
                            otherwise
                                moveSpeed = 1.5;
                        end

                        % 如果被毒減速，速度減半
                        if isfield(obj.Enemies(i), 'PoisonSlowed') && obj.Enemies(i).PoisonSlowed
                            moveSpeed = moveSpeed * 0.5;
                        end

                        % 移動邏輯
                        originalPos = obj.Enemies(i).Position;
                        newPos = originalPos + normalizedDirection * moveSpeed;

                        % 碰撞檢測
                        willCollideWithPlayer = obj.checkAABBCollision(newPos, 40, obj.Player.Position, obj.Player.Size);
                        willCollideWithEnemy = false;
                        for j = 1:length(obj.Enemies)
                            if i ~= j && obj.checkAABBCollision(newPos, 40, obj.Enemies(j).Position, 40)
                                willCollideWithEnemy = true;
                                break;
                            end
                        end

                        if ~willCollideWithPlayer && ~willCollideWithEnemy
                            obj.Enemies(i).Position = newPos;
                            obj.Enemies(i).IsMoving = true;
                        else
                            obj.Enemies(i).IsMoving = false;
                        end
                    end

                    % 更新動畫
                    if obj.Enemies(i).IsAttacking
                        obj.updateEnemyAttackAnimation(i);
                    else
                        obj.updateEnemyAnimation(i);
                    end
                    % 更新敵人圖形位置
                    % updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                    obj.updateEnemyPosition(i);

                end
            end

            obj.updateBossHealthBar();

        end

        function updateBossHealthBar(obj)
            if isempty(obj.BossHealthBars) || ...
                    ~isfield(obj.BossHealthBars, 'FG') || ...
                    ~isvalid(obj.BossHealthBars.FG)
                return;
            end

            for i = 1:length(obj.Enemies)
                if strcmp(obj.Enemies(i).Type, 'boss')
                    pos = obj.Enemies(i).Position;
                    currentHP = obj.Enemies(i).Health;
                    maxHP = 40;

                    hpRatio = max(0, min(1, currentHP/maxHP));
                    fgWidth = obj.BossHealthBars.Width * hpRatio;
                    offsetY = obj.BossHealthBars.OffsetY;

                    % 檢查是否還有效，才更新
                    if isvalid(obj.BossHealthBars.FG)
                        obj.BossHealthBars.FG.Position = ...
                            [pos(1) - obj.BossHealthBars.Width / 2, pos(2) + offsetY, fgWidth, 10];
                    end
                    if isvalid(obj.BossHealthBars.BG)
                        obj.BossHealthBars.BG.Position = ...
                            [pos(1) - obj.BossHealthBars.Width / 2, pos(2) + offsetY, obj.BossHealthBars.Width, 10];
                    end

                    break;
                end
            end
        end

        function checkBulletCollisions(obj)
            % 無子彈或敵人則跳過
            if isempty(obj.Bullets) || isempty(obj.Enemies)
                return;
            end

            % 標記要刪除的子彈
            bulletsToRemove = false(1, length(obj.Bullets));
            % 標記要刪除的敵人
            enemiesToRemove = false(1, length(obj.Enemies));

            % 檢查每顆子彈與每個敵人是否碰撞
            for b = 1:length(obj.Bullets)
                % 確保子彈圖形有效
                if ~isfield(obj.Bullets(b), 'Graphic') || ~isvalid(obj.Bullets(b).Graphic)
                    bulletsToRemove(b) = true;
                    continue;
                end

                if obj.Bullets(b).IsBossBullet
                    % 處理 Boss 子彈與玩家碰撞
                    dist = norm(obj.Bullets(b).Position-obj.Player.Position);
                    collisionRadius = obj.Player.Size / 2;

                    % 確定子彈本身的大小
                    if isfield(obj.Bullets(b), 'Size')
                        bulletSize = obj.Bullets(b).Size;
                    else
                        bulletSize = 15; % 預設大小
                    end

                    if dist < (collisionRadius + bulletSize)
                        obj.Player.Health = obj.Player.Health - obj.Bullets(b).Damage;
                        % 播放受擊音效
                        try
                            if ~isempty(obj.HitSEPlayer) && isvalid(obj.HitSEPlayer)
                                if isplaying(obj.HitSEPlayer)
                                    stop(obj.HitSEPlayer);
                                    obj.HitSEPlayer.CurrentSample = 1;
                                end
                                play(obj.HitSEPlayer);
                            end
                        catch
                        end
                        bulletsToRemove(b) = true;
                    end

                else
                    for e = 1:length(obj.Enemies)
                        if isfield(obj.Enemies(e), 'Graphic') && isvalid(obj.Enemies(e).Graphic)
                            if strcmp(obj.Enemies(e).Type, 'boss')
                                % BOSS使用矩形碰撞檢測
                                collision = obj.checkCollision(obj.Bullets(b).Position, 10, obj.Enemies(e).Position, 60, 'circle', 'rectangle');
                            else
                                % 普通敵人使用圓形碰撞檢測
                                collision = obj.checkCollision(obj.Bullets(b).Position, 10, obj.Enemies(e).Position, 30, 'circle', 'circle');
                            end

                            if collision
                                obj.createFlashEffect(e, [1, 1, 0], 0.1);
                                bulletsToRemove(b) = true;
                                obj.Enemies(e).Health = obj.Enemies(e).Health - obj.Player.Attack;
                                if obj.Enemies(e).Health <= 0
                                    enemiesToRemove(e) = true;
                                end
                                break;
                            end
                        end
                    end
                end
            end

            % 刪除碰撞的子彈
            obj.removeBullets(bulletsToRemove);

            % 刪除死亡的敵人
            obj.removeEnemies(enemiesToRemove);
        end


        function resolveEnemyCollisions(obj)
            % 若怪物數量小於2，則不需檢查碰撞
            if length(obj.Enemies) < 2
                return;
            end

            % 檢查每對怪物
            for i = 1:length(obj.Enemies) - 1
                for j = i + 1:length(obj.Enemies)
                    % 檢查碰撞
                    if obj.checkAABBCollision(obj.Enemies(i).Position, 30, ...
                            obj.Enemies(j).Position, 30)
                        % 計算從怪物j到怪物i的方向向量
                        direction = obj.Enemies(i).Position - obj.Enemies(j).Position;

                        % 標準化方向向量
                        if norm(direction) > 0
                            direction = direction / norm(direction);
                        else
                            % 如果在同一點，隨機推開
                            angle = rand() * 2 * pi;
                            direction = [cos(angle), sin(angle)];
                        end

                        % 增加分離距離
                        separation = 5.0; % 增加至5.0（原為2.0）

                        % 分離兩個敵人
                        obj.Enemies(i).Position = obj.Enemies(i).Position + direction * separation;
                        obj.Enemies(j).Position = obj.Enemies(j).Position - direction * separation;

                        % 更新圖形位置
                        updatePosition(obj.Enemies(i).Graphic, obj.Enemies(i).Position);
                        updatePosition(obj.Enemies(j).Graphic, obj.Enemies(j).Position);
                    end
                end
            end
        end
        function checkPlayerEnemyCollision(obj)
            % may have errors when intentionally collide with enemies,
            % u'll be stucked
            % TODO
            % 檢查玩家與敵人碰撞
            if isempty(obj.Enemies)
                return;
            end

            % 檢查每個敵人
            for i = 1:length(obj.Enemies)
                if obj.checkAABBCollision(obj.Player.Position, obj.Player.Size, ...
                        obj.Enemies(i).Position, 30)
                    % 計算從敵人到玩家的方向向量
                    direction = obj.Player.Position - obj.Enemies(i).Position;

                    % 標準化方向向量
                    if norm(direction) > 0
                        direction = direction / norm(direction);
                    else
                        direction = [0, 1]; % 預設方向
                    end

                    % 計算所需的最小分離距離
                    minDistance = (obj.Player.Size + 30) / 2 + 2; % 半尺寸和加上緩衝

                    % 計算目前距離
                    currentDistance = norm(obj.Player.Position-obj.Enemies(i).Position);

                    % 計算需要推開的距離
                    pushDistance = minDistance - currentDistance;

                    % 只有需要分離時才移動
                    if pushDistance > 0
                        obj.Player.Position = obj.Player.Position + direction * pushDistance;
                        updatePosition(obj.Player.Graphic, obj.Player.Position);
                    end

                    return; % 處理完一個碰撞後返回
                end
            end
        end
        function fireBullet(obj, startPos, direction, isBossBullet, attackerAttack)
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');
            newBullet = struct( ...
                'Position', startPos, ...
                'Velocity', [], ...
                'Damage', attackerAttack, ...
                'IsBossBullet', isBossBullet, ...
                'Graphic', [], ...
                'AnimationFrame', 1, ...
                'FrameCount', 1, ...
                'AnimationTimer', 0, ...
                'AnimationSpeed', 0.075, ...
                'Angle', 0, ...
                'Size', 35, ...
                'ImageSize', [0, 0], ...
                'IsImageBullet', false);

            if isBossBullet && ~isempty(obj.FireballFrames)
                % Calculate angle for rotation (in degrees, 0 = right)
                angle = atan2(direction(2), direction(1)) * 180 / pi;

                % Get the first frame
                frame = obj.FireballFrames{1};
                img = frame.Image;
                alpha = frame.Alpha;

                % Rotate the image to point in direction of travel
                rotatedImg = imrotate(img, -angle);
                if ~isempty(alpha)
                    rotatedAlpha = imrotate(alpha, -angle);
                else
                    rotatedAlpha = [];
                end

                % Calculate size and positioning
                [h, w, ~] = size(rotatedImg);

                % Create fireball image
                hold(obj.GameAxes, 'on');
                if ~isempty(rotatedAlpha)
                    h_img = image(obj.GameAxes, [startPos(1) - w / 2, startPos(1) + w / 2], ...
                        [startPos(2) - h / 2, startPos(2) + h / 2], ...
                        rotatedImg, 'AlphaData', rotatedAlpha);
                else
                    h_img = image(obj.GameAxes, [startPos(1) - w / 2, startPos(1) + w / 2], ...
                        [startPos(2) - h / 2, startPos(2) + h / 2], ...
                        rotatedImg);
                end
                hold(obj.GameAxes, 'off');

                % Create new bullet with all fields
                newBullet.Velocity = direction * 3;
                newBullet.Graphic = h_img;
                newBullet.FrameCount = length(obj.FireballFrames);
                newBullet.Angle = angle;
                newBullet.Size = 25;
                % newBullet = struct( ...
                %     'Position', startPos, ...
                %     'Velocity', direction*3, ...
                %     'Damage', attackerAttack, ...
                %     'IsBossBullet', true, ...
                %     'Graphic', h_img, ...
                %     'AnimationFrame', 1, ...
                %     'FrameCount', length(obj.FireballFrames), ...
                %     'AnimationTimer', 0, ...
                %     'AnimationSpeed', 0.075, ...
                %     'Angle', angle, ...
                %     'Size', 25);
            else
                % 玩家子彈使用預旋轉圖片
                if ~isempty(obj.PlayerBulletFrames)
                    angle = atan2(direction(2), direction(1)) * 180 / pi;
                    angleIndex = mod(round(angle / obj.BulletAngleStep), obj.NumBulletAngles) + 1;

                    bulletFrame = obj.PlayerBulletFrames{angleIndex};
                    [h, w, ~] = size(bulletFrame.Image);

                    % 計算顯示尺寸
                    scaleFactor = newBullet.Size / max(h, w);
                    displayW = w * scaleFactor;
                    displayH = h * scaleFactor;

                    % 創建圖形對象
                    newBullet.Graphic = image(obj.GameAxes, ...
                        [startPos(1) - displayW / 2, startPos(1) + displayW / 2], ...
                        [startPos(2) - displayH / 2, startPos(2) + displayH / 2], ...
                        bulletFrame.Image, 'AlphaData', bulletFrame.Alpha);

                    % 子彈參數
                    newBullet.Velocity = direction * 15;
                    newBullet.ImageSize = [displayW, displayH];
                    newBullet.IsImageBullet = true;
                else
                    % 備用圓形子彈
                    newBullet.Graphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o', ...
                        'MarkerSize', 8, 'MarkerFaceColor', [0, 0, 0]);
                    newBullet.Velocity = direction * 15;
                end
            end

            % Add to bullets array
            if isempty(obj.Bullets)
                obj.Bullets = newBullet;
            else
                obj.Bullets(end+1) = newBullet;
            end
            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function removeBullets(obj, indices)
            % 若沒有要刪除的子彈，直接返回
            if ~any(indices)
                return;
            end

            % 刪除圖形對象
            for i = find(indices)
                delete(obj.Bullets(i).Graphic);
            end

            % 從陣列中刪除
            obj.Bullets(indices) = [];
        end
        function removeEnemies(obj, indices)
            % 若沒有要刪除的敵人，直接返回
            if ~any(indices)
                return;
            end
            boss_dead = false;

            % 刪除圖形對象並累計「小怪死亡」，同時把玩家攻擊力 +1
            for i = find(indices)
                % 先看這隻敵人是不是 Boss，如果不是就當作小怪
                if isfield(obj.Enemies(i), 'Type') && ~strcmp(obj.Enemies(i).Type, 'boss')
                    % 小怪被殺，普通攻擊力 +1
                    obj.Player.Attack = obj.Player.Attack + 1;
                    % （可選）馬上更新畫面上的 AttackLabel：
                    if isvalid(obj.AttackLabel)
                        obj.AttackLabel.Text = sprintf('攻擊力: %d', obj.Player.Attack);
                    end
                end

                % 如果這是 Boss，就記錄一下讓後面顯示勝利畫面
                if isfield(obj.Enemies(i), 'Type') && strcmp(obj.Enemies(i).Type, 'boss')
                    boss_dead = true;
                    % 同時把 Boss 的技能警示圖形也刪掉（如果有）
                    if ~isempty(obj.Enemies(i).SkillWarning) && isgraphics(obj.Enemies(i).SkillWarning)
                        delete(obj.Enemies(i).SkillWarning);
                    end
                end

                % 再把這隻敵人的主圖形刪掉
                if isfield(obj.Enemies(i), 'Graphic') && isgraphics(obj.Enemies(i).Graphic)
                    delete(obj.Enemies(i).Graphic);
                end
            end

            % 實際從陣列中移除這些敵人
            obj.Enemies(indices) = [];

            if (boss_dead)
                obj.showVictoryScreen();
                obj.LevelsCleared(obj.CurrentLevel) = true; %0605

                % 解鎖下一關0605
                if obj.CurrentLevel < 3
                    obj.LevelUnlocked(obj.CurrentLevel+1) = true;
                    obj.LevelButtons(obj.CurrentLevel+1).Enable = 'on';
                end
            end

        end
        function cleanupGameState(obj)
            % 重置遊戲狀態
            obj.isPaused = false;

            % 清理遊戲對象
            if ~isempty(obj.Bullets)
                for i = 1:length(obj.Bullets)
                    if isfield(obj.Bullets(i), 'Graphic') && isvalid(obj.Bullets(i).Graphic)
                        delete(obj.Bullets(i).Graphic);
                    end
                end
                obj.Bullets = struct('Position', {}, 'Velocity', {}, 'Damage', {}, 'IsBossBullet', {}, ...
                    'Graphic', {}, 'AnimationFrame', {}, 'FrameCount', {}, ...
                    'AnimationTimer', {}, 'AnimationSpeed', {}, 'Angle', {}, 'Size', {});

            end

            % 清理玩家資訊標籤
            try
                if ~isempty(obj.HealthLabel) && isvalid(obj.HealthLabel)
                    delete(obj.HealthLabel);
                end
            catch
                % 忽略錯誤
            end
            obj.HealthLabel = [];

            try
                if ~isempty(obj.AttackLabel) && isvalid(obj.AttackLabel)
                    delete(obj.AttackLabel);
                end
            catch
                % 忽略錯誤
            end
            obj.AttackLabel = [];

            % 清理計時器
            try
                if ~isempty(obj.GameTimer) && isvalid(obj.GameTimer)
                    stop(obj.GameTimer);
                    delete(obj.GameTimer);
                end
            catch
            end
            obj.GameTimer = [];

            % 清理時間標籤
            try
                if ~isempty(obj.TimeLabel) && isvalid(obj.TimeLabel)
                    delete(obj.TimeLabel);
                end
            catch

            end
            obj.TimeLabel = [];

            % 清理敵人與玩家
            if ~isempty(obj.Enemies)
                for i = 1:length(obj.Enemies)
                    % 清理閃爍計時器
                    if isfield(obj.Enemies(i), 'FlashTimer') && ~isempty(obj.Enemies(i).FlashTimer) && isvalid(obj.Enemies(i).FlashTimer)
                        stop(obj.Enemies(i).FlashTimer);
                        delete(obj.Enemies(i).FlashTimer);
                    end
                    % 清理圖形
                    if isfield(obj.Enemies(i), 'Graphic') && isgraphics(obj.Enemies(i).Graphic)
                        delete(obj.Enemies(i).Graphic);
                    end
                    % 清理boss技能警示
                    if isfield(obj.Enemies(i), 'SkillWarning') && ...
                            ~isempty(obj.Enemies(i).SkillWarning) && ...
                            isgraphics(obj.Enemies(i).SkillWarning)
                        delete(obj.Enemies(i).SkillWarning);
                    end
                end
            end
            obj.Enemies = struct('Type', {}, 'Position', {}, ...
                'Health', {}, 'Attack', {}, 'AttackRange', {}, ...
                'AttackCooldown', {}, 'SkillCooldown', {}, ...
                'SkillMaxCooldown', {}, 'SkillWarning', {}, ...
                'SkillWarningTimer', {}, 'PoisonSlowed', {}, ...
                'SlowTimer', {}, 'Graphic', {}, 'MarkedForDeletion', {}, ...
                'Direction', {}, 'AnimationFrame', {}, 'AnimationTimer', {}, ...
                'IsMoving', {}, 'IsAttacking', {}, 'AttackAnimationFrame', {}, ...
                'AttackAnimationTimer', {}, 'AttackDirection', {}, 'HasDamaged', {}, ...
                'IsHurt', {}, 'HurtTimer', {}, 'OriginalDirection', {}, ...
                'OriginalAlpha', {}, 'OriginalColor', {}, 'IsFlashing', {}, 'FlashTimer', {});

            if isfield(obj, 'Player') && ~isempty(obj.Player) && isfield(obj.Player, 'Graphic') && isvalid(obj.Player.Graphic)
                delete(obj.Player.Graphic);
            end
            if ~isempty(obj.HeadGraphic) && isvalid(obj.HeadGraphic)
                delete(obj.HeadGraphic);
            end
            obj.HeadGraphic = [];
            obj.Player = [];
            obj.BossAdded = false;

            % 清理技能UI標籤
            try
                if ~isempty(obj.SkillLabel) && isvalid(obj.SkillLabel)
                    delete(obj.SkillLabel);
                end
            catch
            end
            obj.SkillLabel = [];

            % 清理技能說明標籤
            try
                if ~isempty(obj.SkillDescLabel) && isvalid(obj.SkillDescLabel)
                    delete(obj.SkillDescLabel);
                end
            catch
            end
            obj.SkillDescLabel = [];

            % 清理技能圖標
            try
                if ~isempty(obj.SkillIcon) && isvalid(obj.SkillIcon)
                    delete(obj.SkillIcon);
                end
            catch
            end
            obj.SkillIcon = [];

            % 清理技能動畫效果
            for i = 1:length(obj.SkillEffects)
                if ~isempty(obj.SkillEffects{i}) && ...
                        isfield(obj.SkillEffects{i}, 'Graphic') && ...
                        ~isempty(obj.SkillEffects{i}.Graphic) && ...
                        isvalid(obj.SkillEffects{i}.Graphic)
                    delete(obj.SkillEffects{i}.Graphic);
                end
            end
            obj.SkillEffects = {};

            % 重置技能冷卻
            obj.SkillCooldown = 0;

            % 清理第二個技能UI
            try
                if ~isempty(obj.Skill2Label) && isvalid(obj.Skill2Label)
                    delete(obj.Skill2Label);
                end
            catch
            end
            obj.Skill2Label = [];

            try
                if ~isempty(obj.Skill2DescLabel) && isvalid(obj.Skill2DescLabel)
                    delete(obj.Skill2DescLabel);
                end
            catch
            end
            obj.Skill2DescLabel = [];

            try
                if ~isempty(obj.Skill2Icon) && isvalid(obj.Skill2Icon)
                    delete(obj.Skill2Icon);
                end
            catch
            end
            obj.Skill2Icon = [];

            % 清理毒藥水投擲物
            for i = 1:length(obj.PoisonProjectiles)
                if ~isempty(obj.PoisonProjectiles{i}) && ...
                        isfield(obj.PoisonProjectiles{i}, 'Graphic') && ...
                        isvalid(obj.PoisonProjectiles{i}.Graphic)
                    delete(obj.PoisonProjectiles{i}.Graphic);
                end
            end
            obj.PoisonProjectiles = {};

            % 清理毒區域
            for i = 1:length(obj.PoisonAreas)
                if ~isempty(obj.PoisonAreas{i}) && ...
                        isfield(obj.PoisonAreas{i}, 'Graphic') && ...
                        isvalid(obj.PoisonAreas{i}.Graphic)
                    delete(obj.PoisonAreas{i}.Graphic);
                end
            end
            obj.PoisonAreas = {};

            % 重置第二個技能冷卻
            obj.Skill2Cooldown = 0;

            % 清理第三個技能UI
            try
                if ~isempty(obj.Skill3Label) && isvalid(obj.Skill3Label)
                    delete(obj.Skill3Label);
                end
            catch
            end
            obj.Skill3Label = [];

            try
                if ~isempty(obj.Skill3DescLabel) && isvalid(obj.Skill3DescLabel)
                    delete(obj.Skill3DescLabel);
                end
            catch
            end
            obj.Skill3DescLabel = [];

            try
                if ~isempty(obj.Skill3Icon) && isvalid(obj.Skill3Icon)
                    delete(obj.Skill3Icon);
                end
            catch
            end
            obj.Skill3Icon = [];

            % 清理動畫
            % 技能1
            for i = 1:length(obj.Skill1Animations)
                if ~isempty(obj.Skill1Animations{i}) && ...
                        isfield(obj.Skill1Animations{i}, 'Graphic') && ...
                        ~isempty(obj.Skill1Animations{i}.Graphic) && ...
                        isgraphics(obj.Skill1Animations{i}.Graphic)
                    delete(obj.Skill1Animations{i}.Graphic);
                end
            end
            obj.Skill1Animations = {};

            % 技能3
            if ~isempty(obj.Skill3Animation) && isfield(obj.Skill3Animation, 'Graphic') && ...
                    ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                delete(obj.Skill3Animation.Graphic);
            end
            obj.Skill3Animation = [];

            % 重置第三個技能冷卻
            obj.Skill3Cooldown = 0;

            obj.EnemySpawnTimer = 0;

            obj.PlayerBulletFrames = {};

            % 清理BOSS毒藥水投擲物
            for i = 1:length(obj.BossPoisonProjectiles)
                if ~isempty(obj.BossPoisonProjectiles{i}) && ...
                        isfield(obj.BossPoisonProjectiles{i}, 'Graphic') && ...
                        isvalid(obj.BossPoisonProjectiles{i}.Graphic)
                    delete(obj.BossPoisonProjectiles{i}.Graphic);
                end
            end
            obj.BossPoisonProjectiles = {};

            % 清理BOSS毒區域
            for i = 1:length(obj.BossPoisonAreas)
                if ~isempty(obj.BossPoisonAreas{i}) && ...
                        isfield(obj.BossPoisonAreas{i}, 'Graphic') && ...
                        isvalid(obj.BossPoisonAreas{i}.Graphic)
                    delete(obj.BossPoisonAreas{i}.Graphic);
                end
            end
            obj.BossPoisonAreas = {};

            % 清理BOSS大爆炸相關資源
            if ~isempty(obj.BossExplosionWarning) && isvalid(obj.BossExplosionWarning)
                delete(obj.BossExplosionWarning);
                obj.BossExplosionWarning = [];
            end

            if ~isempty(obj.BossExplosionEffect) && isvalid(obj.BossExplosionEffect)
                delete(obj.BossExplosionEffect);
                obj.BossExplosionEffect = [];
            end

            obj.BossExplosionActive = false;
            obj.BossExplosionTimer = 0;
            obj.BossExplosionScheduled = false;
            obj.cleanupBoss3Warning();

        end


        function showVictoryScreen(obj)
            % 先將當前關卡的「下一關」解鎖
            current = obj.CurrentLevel; % 這裡假設 CurrentLevel 已經是剛打完的關卡編號
            if current < 3
                obj.LevelUnlocked(current+1) = true; % 解鎖下一關
                % 如果 LevelButtons 已經建立，立刻將對應按鈕設為可用
                if isprop(obj, 'LevelButtons') && numel(obj.LevelButtons) >= current + 1
                    btn_next = obj.LevelButtons(current+1);
                    if isvalid(btn_next)
                        btn_next.Enable = 'on';
                    end
                end
            end

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

        function BossWarning(obj, state)
            switch state
                case 'start'

                    % 計算BOSS生成位置
                    bossPos = [obj.gameWidth / 2, obj.gameHeight - 100];

                    % 創建半透明紅色標記
                    obj.BossWarningGraphic = rectangle(obj.GameAxes, ...
                        'Position', [bossPos(1) - 50, bossPos(2) - 50, 100, 100], ...
                        'FaceColor', [1, 0, 0], ...
                        'FaceAlpha', 0.3, ...
                        'EdgeColor', 'none', ...
                        'Curvature', 0.3);

                    % 啟動閃爍效果
                    obj.startBlink();
                    % end

                case 'end'

                    % 移除閃爍計時器
                    if ~isempty(obj.BlinkTimer) && isvalid(obj.BlinkTimer)
                        stop(obj.BlinkTimer);
                        delete(obj.BlinkTimer);
                        obj.BlinkTimer = [];
                    end

                    % 移除預警圖形
                    if isvalid(obj.BossWarningGraphic)
                        delete(obj.BossWarningGraphic);
                        obj.BossWarningGraphic = [];
                    end
            end
        end
        function updateTimer(obj)
            % 1. 依照當前關卡取出對應的 BOSS 出場秒數
            lvl = obj.CurrentLevel; % 1, 2 或 3
            appearT = obj.BossAppearTimes(lvl); % 16、13 或 10
            flickerT = appearT - 3; % 閃爍開始時間

            % 2. 更新累計秒數
            obj.ElapsedTime = obj.ElapsedTime + 1;
            minutes = floor(obj.ElapsedTime/60);
            seconds = mod(obj.ElapsedTime, 60);

            % 3. 更新畫面上的時間顯示
            obj.TimeStr = sprintf('%02d:%02d', minutes, seconds);
            if isvalid(obj.TimeLabel)
                obj.TimeLabel.Text = ['時間: ', obj.TimeStr];
            end

            % 4. 如果尚未加過 BOSS，且累計秒數剛好到達 (appearT - 3)，觸發閃爍預警
            if obj.ElapsedTime == flickerT && ~obj.BossAdded
                obj.BossWarning('start');
            end

            % 5. 如果尚未加過 BOSS，且累計秒數 >= appearT，就真正生成 BOSS 並結束閃爍
            if ~obj.BossAdded && obj.ElapsedTime >= appearT && strcmp(obj.GameState, 'PLAYING')
                obj.BossWarning('end');
                obj.initBOSS();

                % 第三關特殊處理：設定爆炸時間
                if obj.CurrentLevel == 3
                    obj.BossExplosionScheduled = true;
                    fprintf('第三關BOSS已出現！將在遊戲時間20秒時爆炸！\n');
                end
            end

            % 6. 第三關BOSS爆炸檢查
            if obj.CurrentLevel == 3 && obj.BossExplosionScheduled && strcmp(obj.GameState, 'PLAYING')
                timeLeft = obj.BossExplosionTime - obj.ElapsedTime;

                % 爆炸前5秒開始警告
                if timeLeft <= 5 && timeLeft > 0 && ~obj.Boss3WarningActive
                    obj.startBoss3ExplosionWarning();
                end

                % 時間到，執行爆炸
                if obj.ElapsedTime >= obj.BossExplosionTime
                    fprintf('時間到！BOSS執行致命爆炸！\n');
                    obj.executeFinalBossExplosion();
                    obj.BossExplosionScheduled = false;
                end

                % 更新警告顯示
                if obj.Boss3WarningActive && timeLeft > 0
                    obj.updateBoss3Warning(timeLeft);
                end
            end
            % 第三關倒數警告
            if obj.CurrentLevel == 3 && obj.BossAdded && obj.BossExplosionScheduled
                timeLeft = obj.BossExplosionTime - obj.ElapsedTime;
                if timeLeft <= 10 && timeLeft > 0 % 最後10秒警告
                    if isvalid(obj.TimeLabel)
                        obj.TimeLabel.Text = sprintf('時間: %s (危險！%d秒後爆炸！)', obj.TimeStr, timeLeft);
                        obj.TimeLabel.FontColor = [1, 0, 0]; % 紅色警告
                    end
                elseif timeLeft <= 0
                    if isvalid(obj.TimeLabel)
                        obj.TimeLabel.Text = sprintf('時間: %s (爆炸！)', obj.TimeStr);
                    end
                end
            end
        end


        function loadPlayerAnimations(obj)
            % 加載靜止(idle)動畫
            idlePath = fullfile(obj.basePath, 'images', 'body', 'idle.png');
            runPath = fullfile(obj.basePath, 'images', 'body', 'run.png');

            try
                [idleSheet, ~, idleAlpha] = imread(idlePath);
                [runSheet, ~, runAlpha] = imread(runPath);

                % 設定幀數和方向數
                numDirections = 4; % 上、左、下、右

                % 正確分割 idle 表 (第2列的圖片)
                idleFrameHeight = floor(size(idleSheet, 1)/4); % 確保整數
                idleFrameWidth = floor(size(idleSheet, 2)/2); % 確保整數

                % idle取第2列
                idleCol = 2;
                obj.IdleFrames = cell(numDirections, 1);

                % 分配4個方向的靜態幀 (上、左、下、右)
                for dir = 1:numDirections
                    % 計算當前方向幀的位置 (第2列的位置)
                    startY = floor((dir - 1)*idleFrameHeight) + 1;
                    startX = floor((idleCol - 1)*idleFrameWidth) + 1;
                    endY = floor(startY+idleFrameHeight-1);
                    endX = floor(startX + idleFrameWidth - 1);

                    % 範圍安全檢查
                    endY = min(endY, size(idleSheet, 1));
                    endX = min(endX, size(idleSheet, 2));

                    % 提取單一幀
                    frame = idleSheet(startY:endY, startX:endX, :);
                    alpha = idleAlpha(startY:endY, startX:endX);

                    frame = flipud(frame);
                    alpha = flipud(alpha);

                    obj.IdleFrames{dir} = struct('Image', frame, 'Alpha', alpha);
                end

                % 處理運行動畫 - 每個方向有8幀
                runFrameHeight = floor(size(runSheet, 1)/4); % 確保整數
                runFrameWidth = floor(size(runSheet, 2)/8); % 確保整數

                obj.RunFrames = cell(numDirections, 8); % 4個方向，每個方向8幀

                % 分配每個方向的運行幀
                for dir = 1:numDirections
                    for frame = 1:8
                        % 計算當前幀的位置
                        startY = floor((dir - 1)*runFrameHeight) + 1;
                        startX = floor((frame - 1)*runFrameWidth) + 1;
                        endY = floor(startY+runFrameHeight-1);
                        endX = floor(startX + runFrameWidth - 1);

                        % 範圍安全檢查
                        endY = min(endY, size(runSheet, 1));
                        endX = min(endX, size(runSheet, 2));

                        % 提取幀和Alpha通道
                        frameImg = runSheet(startY:endY, startX:endX, :);
                        frameAlpha = runAlpha(startY:endY, startX:endX);

                        frameImg = flipud(frameImg);
                        frameAlpha = flipud(frameAlpha);

                        obj.RunFrames{dir, frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                    end
                end

                % 設置初始狀態
                obj.CurrentDirection = 3; % 預設向下
                obj.IsMoving = false;
                obj.CurrentFrame = 1;
                obj.AnimationTimer = 0;
                obj.AnimationSpeed = 0.1; % 動畫速度

            catch ME
                warning(ME.identifier, '載入動畫失敗：%s', ME.message);
                obj.IdleFrames = {};
                obj.RunFrames = {};
            end
            try
                % 載入頭部跑步動畫
                headRunPath = fullfile(obj.basePath, 'images', 'head', 'head_run.png');
                [headRunSheet, ~, headRunAlpha] = imread(headRunPath);

                % head_run.png 是 4行8列：上、左、下、右 × 8幀
                numDirections = 4;
                numFrames = 8;

                headFrameHeight = floor(size(headRunSheet, 1)/4);
                headFrameWidth = floor(size(headRunSheet, 2)/8);

                obj.HeadRunFrames = cell(numDirections, numFrames);

                % 載入每個方向的每一幀
                for dir = 1:numDirections
                    for frame = 1:numFrames
                        % 計算當前幀位置
                        startY = floor((dir - 1)*headFrameHeight) + 1;
                        startX = floor((frame - 1)*headFrameWidth) + 1;
                        endY = floor(startY+headFrameHeight-1);
                        endX = floor(startX + headFrameWidth - 1);

                        % 範圍安全檢查
                        endY = min(endY, size(headRunSheet, 1));
                        endX = min(endX, size(headRunSheet, 2));

                        % 提取幀
                        frameImg = headRunSheet(startY:endY, startX:endX, :);
                        frameAlpha = headRunAlpha(startY:endY, startX:endX);

                        % 翻轉圖像（與身體保持一致）
                        frameImg = flipud(frameImg);
                        frameAlpha = flipud(frameAlpha);

                        obj.HeadRunFrames{dir, frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                    end
                end

                fprintf('頭部動畫載入成功\n');

            catch ME
                warning(ME.identifier, '載入頭部動畫失敗：%s', ME.message);
                obj.HeadRunFrames = {};
            end
        end


        function handleKeyRelease(obj, event)
            % 遊戲進行中才處理按鍵釋放
            if ~obj.isPaused && strcmp(obj.GameState, 'PLAYING')
                % 更新按鍵狀態
                if ismember(event.Key, {'w', 'a', 's', 'd'})
                    obj.KeysPressed.(event.Key) = false;

                    % 檢查是否還有其他方向鍵被按下
                    if ~any(structfun(@(x) x, obj.KeysPressed))
                        obj.IsMoving = false;
                    else
                        % 更新移動方向為最後一個還在按下的方向鍵
                        if obj.KeysPressed.w
                            obj.CurrentDirection = 1; % 上
                        elseif obj.KeysPressed.a
                            obj.CurrentDirection = 2; % 左
                        elseif obj.KeysPressed.s
                            obj.CurrentDirection = 3; % 下
                        elseif obj.KeysPressed.d
                            obj.CurrentDirection = 4; % 右
                        end
                    end
                end
            end
        end

        function useSkill(obj)
            % ----------------------------------------------------------------------------
            % Step 0：印出當前狀態，方便除錯
            fprintf('** 嘗試使用技能1：Skill1UseCount = %d，SkillCooldown = %.2f **\n', ...
                obj.Skill1UseCount, obj.SkillCooldown);
            % ----------------------------------------------------------------------------

            % 1. 如果還在冷卻，就直接不執行
            if obj.SkillCooldown > 0
                fprintf('  => 技能1仍在冷卻 (%.2f)，不執行\n', obj.SkillCooldown);
                return;
            end

            % 2. 檢查是否已經到達最大使用次數
            if obj.Skill1UseCount >= obj.Skill1MaxUses
                fprintf('  => 技能1已用滿 %d 次，不再執行\n', obj.Skill1MaxUses);
                return;
            end

            % 3. 增加已用次數
            obj.Skill1UseCount = obj.Skill1UseCount + 1;
            fprintf('  => 執行技能1！ (是本關第 %d 次使用)\n', obj.Skill1UseCount);

            % 4. 隱藏圖示 (或更新 UI)
            if isvalid(obj.SkillIcon)
                obj.SkillIcon.Visible = 'off';
            end

            % 5. 使用技能：造成範圍傷害並播動畫
            skillDamage = obj.Player.Attack * 3;
            skillRadius = 60;
            obj.createAreaDamage(obj.MousePos, skillRadius, skillDamage);
            obj.createSkillAnimation(obj.MousePos, skillRadius);

            % 6. 設置冷卻時間
            obj.SkillCooldown = obj.SkillMaxCooldown;
            if isvalid(obj.SkillLabel)
                obj.SkillLabel.Visible = 'on';
            end
        end


        function createAreaDamage(obj, center, radius, damage)
            % 檢查範圍內的敵人
            if isempty(obj.Enemies)
                return;
            end

            enemiesToRemove = false(1, length(obj.Enemies));

            for i = 1:length(obj.Enemies)
                % 計算敵人與技能中心的距離
                distance = norm(obj.Enemies(i).Position-center);

                % 如果在範圍內，造成傷害
                if distance <= radius
                    obj.Enemies(i).Health = obj.Enemies(i).Health - damage;

                    if obj.Enemies(i).Health <= 0
                        enemiesToRemove(i) = true;
                    end

                    % 受傷閃爍
                    if isvalid(obj.Enemies(i).Graphic)
                        % pause(0.05); % don't use pause
                        obj.createFlashEffect(i, [1, 1, 0], 0.05);
                    end

                end
            end

            % 移除死亡的敵人
            obj.removeEnemies(enemiesToRemove);
        end

        function createFlashEffect(obj, enemyIndex, flashColor, duration)
            % 使用受傷動畫效果
            if enemyIndex > length(obj.Enemies) || ...
                    ~isfield(obj.Enemies(enemyIndex), 'Graphic') || ...
                    ~isvalid(obj.Enemies(enemyIndex).Graphic)
                return;
            end

            % 跳過BOSS，BOSS保持原有的閃爍效果
            if strcmp(obj.Enemies(enemyIndex).Type, 'boss')
                obj.createBossFlashEffect(enemyIndex, flashColor, duration);
                return;
            end

            % 普通敵人使用受傷動畫
            if ~isempty(obj.EnemyHurtFrames)
                % 記錄原始狀態
                obj.Enemies(enemyIndex).IsHurt = true;
                obj.Enemies(enemyIndex).HurtTimer = duration;
                obj.Enemies(enemyIndex).OriginalDirection = obj.Enemies(enemyIndex).Direction;

                % 切換到受傷圖片
                if isvalid(obj.Enemies(enemyIndex).Graphic) && isa(obj.Enemies(enemyIndex).Graphic, 'matlab.graphics.primitive.Image')
                    hurtFrame = obj.EnemyHurtFrames{obj.Enemies(enemyIndex).Direction};
                    obj.Enemies(enemyIndex).Graphic.CData = hurtFrame.Image;
                    obj.Enemies(enemyIndex).Graphic.AlphaData = hurtFrame.Alpha;
                end
            else
                % 備用：使用原有的閃爍效果
                obj.createBossFlashEffect(enemyIndex, flashColor, duration);
            end
        end

        function createBossFlashEffect(obj, enemyIndex, flashColor, duration)
            % BOSS閃爍效果（修正透明度累積問題）

            % 檢查敵人是否存在
            if enemyIndex > length(obj.Enemies)
                return;
            end

            enemy = obj.Enemies(enemyIndex);
            enemyGraphic = enemy.Graphic;

            % 如果已經在閃爍中，取消之前的計時器
            if isfield(enemy, 'IsFlashing') && enemy.IsFlashing && ...
                    isfield(enemy, 'FlashTimer') && ~isempty(enemy.FlashTimer) && isvalid(enemy.FlashTimer)
                stop(enemy.FlashTimer);
                delete(enemy.FlashTimer);
            end

            if isa(enemyGraphic, 'matlab.graphics.primitive.Rectangle')
                % Rectangle 類型處理
                if ~isfield(enemy, 'OriginalColor') || isempty(enemy.OriginalColor)
                    enemy.OriginalColor = enemyGraphic.FaceColor;
                    obj.Enemies(enemyIndex).OriginalColor = enemy.OriginalColor;
                end

                if isvalid(enemyGraphic)
                    enemyGraphic.FaceColor = flashColor;

                    obj.Enemies(enemyIndex).IsFlashing = true;
                    restoreTimer = timer( ...
                        'StartDelay', duration, ...
                        'TimerFcn', @(src, event) obj.restoreEnemyColor(enemyIndex), ...
                        'ExecutionMode', 'singleShot');
                    obj.Enemies(enemyIndex).FlashTimer = restoreTimer;
                    start(restoreTimer);
                end

            elseif isa(enemyGraphic, 'matlab.graphics.primitive.Image')
                % Image 類型處理（修正透明度問題）
                try
                    % 如果沒有保存原始透明度，現在保存
                    if ~isfield(enemy, 'OriginalAlpha') || isempty(enemy.OriginalAlpha)
                        originalAlpha = get(enemyGraphic, 'AlphaData');
                        if isempty(originalAlpha)
                            originalAlpha = ones(size(get(enemyGraphic, 'CData'), 1), size(get(enemyGraphic, 'CData'), 2));
                        end
                        obj.Enemies(enemyIndex).OriginalAlpha = originalAlpha;
                    end

                    % 使用保存的原始透明度值計算新的透明度
                    originalAlpha = obj.Enemies(enemyIndex).OriginalAlpha;
                    newAlpha = originalAlpha * 0.3; % 始終基於原始值計算

                    enemyGraphic.AlphaData = newAlpha;

                    obj.Enemies(enemyIndex).IsFlashing = true;
                    restoreTimer = timer( ...
                        'StartDelay', duration, ...
                        'TimerFcn', @(src, event) obj.restoreEnemyAlpha(enemyIndex), ...
                        'ExecutionMode', 'singleShot');
                    obj.Enemies(enemyIndex).FlashTimer = restoreTimer;
                    start(restoreTimer);
                catch ME
                    warning(ME.identifier, 'BOSS閃爍效果失敗：%s', ME.message);
                end
            end
        end


        function restoreEnemyColor(obj, enemyIndex)
            % 恢復敵人顏色（使用索引而不是直接的圖形對象）
            try
                if enemyIndex <= length(obj.Enemies) && isvalid(obj.Enemies(enemyIndex).Graphic)
                    if isfield(obj.Enemies(enemyIndex), 'OriginalColor')
                        obj.Enemies(enemyIndex).Graphic.FaceColor = obj.Enemies(enemyIndex).OriginalColor;
                    end
                    obj.Enemies(enemyIndex).IsFlashing = false;
                    obj.Enemies(enemyIndex).FlashTimer = [];
                end
            catch ME
                warning(ME.identifier, '恢復敵人顏色失敗：%s', ME.message);
            end
        end

        function restoreEnemyAlpha(obj, enemyIndex)
            % 恢復敵人透明度（使用索引和保存的原始值）
            try
                if enemyIndex <= length(obj.Enemies) && isvalid(obj.Enemies(enemyIndex).Graphic)
                    if isfield(obj.Enemies(enemyIndex), 'OriginalAlpha') && ~isempty(obj.Enemies(enemyIndex).OriginalAlpha)
                        obj.Enemies(enemyIndex).Graphic.AlphaData = obj.Enemies(enemyIndex).OriginalAlpha;
                    end
                    obj.Enemies(enemyIndex).IsFlashing = false;
                    obj.Enemies(enemyIndex).FlashTimer = [];
                end
            catch ME
                warning(ME,identifier, '恢復敵人透明度失敗：%s', ME.message);
            end
        end

        function createSkillAnimation(obj, center, radius)
            % 創建技能1動畫效果
            if isempty(obj.Skill1Frames)
                % 如果沒有載入動畫幀，使用原有的圓形效果
                wasHeld = ishold(obj.GameAxes);
                hold(obj.GameAxes, 'on');

                theta = linspace(0, 2*pi, 50);
                x = center(1) + radius * cos(theta);
                y = center(2) + radius * sin(theta);

                skillEffect = fill(obj.GameAxes, x, y, [1, 1, 0], ...
                    'FaceAlpha', 0.6, ...
                    'EdgeColor', [1, 0.8, 0], ...
                    'LineWidth', 3);

                obj.SkillEffects{end+1} = struct('Graphic', skillEffect, 'Timer', 0.5);

                if ~wasHeld
                    hold(obj.GameAxes, 'off');
                end
                return;
            end

            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 使用第一幀創建初始圖像
            firstFrame = obj.Skill1Frames{1};
            [h, w, ~] = size(firstFrame.Image);

            % 計算動畫大小（根據技能範圍調整）
            animationSize = radius * 2; % 動畫大小基於技能範圍
            scaleFactor = animationSize / max(h, w);

            % 創建動畫實例
            newAnimation = struct( ...
                'Position', center, ...
                'FrameIndex', 1, ...
                'FrameTimer', 0, ...
                'FrameInterval', 0.1, ... % 每幀持續0.1秒
                'ScaleFactor', scaleFactor, ...
                'Graphic', [], ...
                'IsActive', true, ...
                'TotalTimer', 0, ...
                'MaxDuration', 0.9 ... % 9幀 × 0.1秒 = 0.9秒
                );

            % 創建第一幀的圖像、接收返回值
            newAnimation = obj.updateSkill1Frame(newAnimation);

            % 添加到動畫列表
            obj.Skill1Animations{end+1} = newAnimation;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        % function with return value
        function animation = updateSkill1Frame(obj, animation)
            % 更新技能1動畫幀 - 返回修改後的動畫結構體
            if ~animation.IsActive || animation.FrameIndex > length(obj.Skill1Frames)
                return;
            end

            % 獲取當前幀
            frame = obj.Skill1Frames{animation.FrameIndex};
            img = frame.Image;
            alpha = frame.Alpha;

            % 計算圖像大小和位置
            [h, w, ~] = size(img);
            scaledW = w * animation.ScaleFactor;
            scaledH = h * animation.ScaleFactor;

            centerPos = animation.Position;

            % 修改位置計算 - 讓動畫底部對應到目標位置
            xData = [centerPos(1) - scaledW / 2, centerPos(1) + scaledW / 2]; % 水平居中
            yData = [centerPos(2), centerPos(2) + scaledH]; % 底部對應到目標位置

            % 如果已有圖像，先刪除
            if ~isempty(animation.Graphic) && isgraphics(animation.Graphic)
                delete(animation.Graphic);
            end

            % 創建新的圖像
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            animation.Graphic = image(obj.GameAxes, xData, yData, img, ...
                'AlphaData', alpha);

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end

            % 返回修改後的動畫結構體
        end


        function updateSkillSystem(obj, deltaTime)
            % 更新技能冷卻
            if obj.SkillCooldown > 0
                obj.SkillCooldown = max(0, obj.SkillCooldown-deltaTime);
            end

            if obj.Skill2Cooldown > 0
                obj.Skill2Cooldown = max(0, obj.Skill2Cooldown-deltaTime);
            end

            % 更新第三個技能冷卻
            if obj.Skill3Cooldown > 0
                obj.Skill3Cooldown = max(0, obj.Skill3Cooldown-deltaTime);
            end
            % 更新技能1動畫
            obj.updateSkill1Animations(deltaTime);

            % 更新原有的技能動畫效果（備用）
            effectsToRemove = [];
            for i = 1:length(obj.SkillEffects)
                obj.SkillEffects{i}.Timer = obj.SkillEffects{i}.Timer - deltaTime;

                if obj.SkillEffects{i}.Timer <= 0
                    % 動畫結束，移除效果
                    if ~isempty(obj.SkillEffects{i}.Graphic) && isgraphics(obj.SkillEffects{i}.Graphic)
                        delete(obj.SkillEffects{i}.Graphic);
                    end
                    effectsToRemove(end+1) = i;
                else
                    % 更新透明度（淡出效果）
                    if ~isempty(obj.SkillEffects{i}.Graphic) && isgraphics(obj.SkillEffects{i}.Graphic)
                        alpha = obj.SkillEffects{i}.Timer / 0.5; % 原始持續時間
                        obj.SkillEffects{i}.Graphic.FaceAlpha = alpha * 0.6;
                    end
                end
            end

            % 移除已結束的動畫效果
            obj.SkillEffects(effectsToRemove) = [];
        end

        function updateSkill1Animations(obj, deltaTime)
            % 更新技能1動畫列表
            animationsToRemove = [];

            for i = 1:length(obj.Skill1Animations)
                animation = obj.Skill1Animations{i};

                if ~animation.IsActive
                    animationsToRemove(end+1) = i;
                    continue;
                end

                % 更新總計時器
                animation.TotalTimer = animation.TotalTimer + deltaTime;
                animation.FrameTimer = animation.FrameTimer + deltaTime;

                % 檢查是否需要切換到下一幀
                if animation.FrameTimer >= animation.FrameInterval
                    animation.FrameTimer = 0;
                    animation.FrameIndex = animation.FrameIndex + 1;

                    % 檢查動畫是否結束
                    if animation.FrameIndex > length(obj.Skill1Frames) || ...
                            animation.TotalTimer >= animation.MaxDuration
                        % 動畫結束，清理
                        if ~isempty(animation.Graphic) && isgraphics(animation.Graphic)
                            delete(animation.Graphic);
                        end
                        animation.IsActive = false;
                        animationsToRemove(end+1) = i;
                    else
                        % 更新到下一幀
                        animation = obj.updateSkill1Frame(animation);
                    end
                end

                % 確保修改後的結構被保存
                obj.Skill1Animations{i} = animation;
            end

            % 移除已結束的動畫
            obj.Skill1Animations(animationsToRemove) = [];
        end


        function updateSkillUI(obj)
            % if can't use, don't show anything about skill
            if ~obj.LevelsCleared(1)
                return;
            end
            if obj.Skill1UseCount >= obj.Skill1MaxUses
                if isvalid(obj.SkillIcon)
                    obj.SkillIcon.Visible = 'off';
                end
                if isvalid(obj.SkillLabel)
                    obj.SkillLabel.Visible = 'off';
                end
                obj.SkillDescLabel.Visible = 'off';
                return;
            end

            % 冷卻邏輯：如果還在冷卻，顯示剩餘秒數並隱藏圖示；否則顯示圖示
            if isvalid(obj.SkillLabel)
                if obj.SkillCooldown > 0
                    obj.SkillLabel.Text = sprintf('%.1f', obj.SkillCooldown);
                    obj.SkillLabel.FontColor = [0.5, 0.5, 0.5];
                    obj.SkillLabel.BackgroundColor = [0.3, 0.3, 0.3];
                    if isvalid(obj.SkillIcon)
                        obj.SkillIcon.Visible = 'off';
                    end
                else
                    obj.SkillLabel.Text = '';
                    obj.SkillLabel.BackgroundColor = [0.1, 0.1, 0.4];
                    obj.SkillLabel.Visible = 'off';
                    if isvalid(obj.SkillIcon)
                        obj.SkillIcon.Visible = 'on';
                    end
                end
            end
        end


        function useBossSkill(obj, bossIndex)
            % boss使用技能
            if obj.Enemies(bossIndex).SkillCooldown > 0
                return; % 技能在冷卻中
            end
            % 根據當前關卡決定boss使用哪種技能
            switch obj.CurrentLevel
                case 1
                    % 第一關：使用範圍攻擊技能
                    obj.useBossSkill1(bossIndex);
                case 2
                    % 第二關：使用毒藥水技能
                    obj.useBossSkill2(bossIndex);
                case 3
                    % 第三關：使用大爆炸技能

                    return; % 直接返回，不執行任何技能，定時爆炸
            end

            % 設置冷卻時間
            obj.Enemies(bossIndex).SkillCooldown = obj.Enemies(bossIndex).SkillMaxCooldown;
        end

        function useBossSkill1(obj, bossIndex)
            % BOSS技能1：範圍攻擊
            targetPos = obj.Player.Position;
            skillRadius = 60; % 技能範圍半徑

            % 開始警示效果
            obj.createBossSkillWarning(bossIndex, targetPos, skillRadius);
        end


        function createBossSkillWarning(obj, bossIndex, center, radius)
            % 創建紅色警示效果
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 創建紅色圓形警示指示器
            theta = linspace(0, 2*pi, 50);
            x = center(1) + radius * cos(theta);
            y = center(2) + radius * sin(theta);

            % 創建填充圓形警示
            warningEffect = fill(obj.GameAxes, x, y, [1, 0, 0], ... % 紅色
                'FaceAlpha', 0.3, ...
                'EdgeColor', [1, 0, 0], ...
                'LineWidth', 2);

            % 存儲警示效果到boss
            obj.Enemies(bossIndex).SkillWarning = warningEffect;
            obj.Enemies(bossIndex).SkillWarningTimer = 1.0; % 警示持續1秒

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function executeBossSkillDamage(obj, bossIndex, center, radius)
            % 執行boss技能傷害
            skillDamage = obj.Enemies(bossIndex).Attack * 1.5;

            % 檢查玩家是否在範圍內
            distance = norm(obj.Player.Position-center);
            if distance <= radius
                obj.Player.Health = obj.Player.Health - skillDamage;

                % 玩家受傷閃爍-deleted,TODO: use sound effect instead

                fprintf('玩家受到Boss技能攻擊，傷害：%.1f\n', skillDamage);
            end

            % 創建技能傷害動畫效果
            obj.createSkillAnimation(center, radius);

        end

        function useSkill2(obj)
            % 1. 檢查本關已使用次數是否大於等於上限
            if obj.Skill2UseCount >= obj.Skill2MaxUses
                return; % 超過三次，直接不執行
            end

            % 2. 檢查是否在冷卻
            if obj.Skill2Cooldown > 0
                return;
            end

            % 3. 增加已用次數
            obj.Skill2UseCount = obj.Skill2UseCount + 1;

            % 4. 隱藏圖示或更新 UI
            obj.Skill2Icon.Visible = 'off';

            % 5. 執行丟毒藥水邏輯
            obj.throwPoisonBottle(obj.Player.Position, obj.MousePos);

            % 6. 設置冷卻
            obj.Skill2Cooldown = obj.Skill2MaxCooldown;
            obj.Skill2Label.Visible = 'on';
        end


        function throwPoisonBottle(obj, startPos, targetPos)
            % 計算投擲方向和距離
            direction = targetPos - startPos;
            distance = norm(direction);

            if distance == 0
                return;
            end

            normalizedDirection = direction / distance;

            % 創建毒藥水投擲物
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 創建投擲物圖形（綠色圓點）
            % TODO: use pictures

            projectileGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o', ...
                'MarkerSize', 12, ...
                'MarkerFaceColor', [0, 0.8, 0], ...
                'MarkerEdgeColor', [0, 0.6, 0], ...
                'LineWidth', 2);

            % 創建投擲物數據
            newProjectile = struct( ...
                'Position', startPos, ...
                'TargetPos', targetPos, ...
                'Speed', 8, ...
                'Graphic', projectileGraphic, ...
                'Direction', normalizedDirection ...
                );

            % 添加到投擲物陣列
            obj.PoisonProjectiles{end+1} = newProjectile;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function createPoisonArea(obj, center)
            % TODO: add animation
            % 創建毒區域效果
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            radius = 120; % 毒區域半徑

            % 創建綠色圓形毒區域
            theta = linspace(0, 2*pi, 50);
            x = center(1) + radius * cos(theta);
            y = center(2) + radius * sin(theta);

            % 創建填充圓形
            poisonArea = fill(obj.GameAxes, x, y, [0, 0.8, 0], ... % 綠色
                'FaceAlpha', 0.4, ...
                'EdgeColor', [0, 0.6, 0], ...
                'LineWidth', 2);

            % 創建毒區域數據
            newPoisonArea = struct( ...
                'Position', center, ...
                'Radius', radius, ...
                'Graphic', poisonArea, ...
                'Timer', 3.0, ... % 持續3秒
                'DamageTimer', 1, ... % 傷害計時器(一開始就造成傷害)
                'DamageInterval', 1.0 ... % 每秒造成傷害
                );

            % 添加到毒區域陣列
            obj.PoisonAreas{end+1} = newPoisonArea;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function updatePoisonProjectiles(obj, deltaTime)
            % 更新毒藥水投擲物
            projectilesToRemove = [];

            for i = 1:length(obj.PoisonProjectiles)
                projectile = obj.PoisonProjectiles{i};

                % 移動投擲物
                projectile.Position = projectile.Position + projectile.Direction * projectile.Speed;

                % 更新圖形位置
                if isvalid(projectile.Graphic)
                    projectile.Graphic.XData = projectile.Position(1);
                    projectile.Graphic.YData = projectile.Position(2);
                end

                % 檢查是否到達目標位置
                distance = norm(projectile.Position-projectile.TargetPos);
                if distance <= 10 % 到達目標位置
                    % 創建毒區域
                    obj.createPoisonArea(projectile.TargetPos);

                    % 移除投擲物
                    if isvalid(projectile.Graphic)
                        delete(projectile.Graphic);
                    end
                    projectilesToRemove(end+1) = i;
                end

                % 更新投擲物數據
                obj.PoisonProjectiles{i} = projectile;
            end

            % 移除已到達的投擲物
            obj.PoisonProjectiles(projectilesToRemove) = [];
        end

        function updatePoisonAreas(obj, deltaTime)
            % 更新毒區域
            areasToRemove = [];

            for i = 1:length(obj.PoisonAreas)
                area = obj.PoisonAreas{i};

                % 更新計時器
                area.Timer = area.Timer - deltaTime;
                area.DamageTimer = area.DamageTimer + deltaTime;

                % 檢查是否需要造成傷害
                if area.DamageTimer >= area.DamageInterval
                    obj.applyPoisonDamage(area);
                    area.DamageTimer = 0;
                end

                % 檢查是否過期
                if area.Timer <= 0
                    % 移除毒區域
                    if isvalid(area.Graphic)
                        delete(area.Graphic);
                    end
                    areasToRemove(end+1) = i;
                else
                    % 更新透明度（漸漸消失效果）
                    if isvalid(area.Graphic)
                        alpha = area.Timer / 3.0; % 原始持續時間
                        area.Graphic.FaceAlpha = alpha * 0.4;
                    end
                end

                % 更新區域數據
                obj.PoisonAreas{i} = area;
            end

            % 移除過期的區域
            obj.PoisonAreas(areasToRemove) = [];
        end

        function applyPoisonDamage(obj, area)
            % 對毒區域內的敵人造成傷害並減速
            if isempty(obj.Enemies)
                return;
            end

            skillDamage = obj.Player.Attack * 1.5;
            enemiesToRemove = false(1, length(obj.Enemies));

            for i = 1:length(obj.Enemies)
                % 計算敵人與毒區域中心的距離
                distance = norm(obj.Enemies(i).Position-area.Position);

                % 如果在毒區域內
                if distance <= area.Radius
                    % 造成傷害
                    obj.Enemies(i).Health = obj.Enemies(i).Health - skillDamage;

                    % 減速標記
                    obj.Enemies(i).PoisonSlowed = true;
                    obj.Enemies(i).SlowTimer = 1.2; % 減速效果持續1.2秒

                    % 檢查死亡
                    if obj.Enemies(i).Health <= 0
                        enemiesToRemove(i) = true; % 標記移除
                    end

                    % 視覺效果
                    if isvalid(obj.Enemies(i).Graphic)
                        % pause(0.05); % don't use pause
                        obj.createFlashEffect(i, [0, 1, 0], 0.05); % 綠色閃爍
                    end
                end
            end

            % 在循環結束後一次性移除所有死亡的敵人
            if any(enemiesToRemove)
                obj.removeEnemies(enemiesToRemove);
            end
        end


        function updateSkill2UI(obj)
            if ~obj.LevelsCleared(2)
                return;
            end

            % 如果已經用滿，則隱藏圖示與 Label，並直接返回
            if obj.Skill2UseCount >= obj.Skill2MaxUses
                if isvalid(obj.Skill2Icon)
                    obj.Skill2Icon.Visible = 'off';
                end
                if isvalid(obj.Skill2Label)
                    obj.Skill2Label.Visible = 'off';
                end
                obj.Skill2DescLabel.Visible='off';
                return;
            end

            % 如果還在冷卻，就顯示剩餘秒數、隱藏圖示
            if isvalid(obj.Skill2Label)
                if obj.Skill2Cooldown > 0
                    obj.Skill2Label.Text = sprintf('%.1f', obj.Skill2Cooldown);
                    obj.Skill2Label.FontColor = [0.5, 0.5, 0.5];
                    obj.Skill2Label.BackgroundColor = [0.3, 0.3, 0.3];
                    if isvalid(obj.Skill2Icon)
                        obj.Skill2Icon.Visible = 'off';
                    end
                else
                    % 冷卻結束，可用狀態下，只顯示圖示
                    obj.Skill2Label.Text = '';
                    obj.Skill2Label.BackgroundColor = [0.1, 0.1, 0.4];
                    obj.Skill2Label.Visible = 'off';
                    if isvalid(obj.Skill2Icon)
                        obj.Skill2Icon.Visible = 'on';
                    end
                end
            end
        end

        function updateSkill3UI(obj)
            if ~obj.LevelsCleared(3)
                return;
            end

            if isvalid(obj.Skill3Label)
                if obj.Skill3Cooldown > 0
                    obj.Skill3Label.Text = sprintf('%.1f', obj.Skill3Cooldown);
                    obj.Skill3Label.FontColor = [0.5, 0.5, 0.5];
                    obj.Skill3Label.BackgroundColor = [0.3, 0.3, 0.3];
                    if isvalid(obj.Skill3Icon)
                        obj.Skill3Icon.Visible = 'off';
                    end
                else
                    obj.Skill3Label.Text = '';
                    obj.Skill3Label.BackgroundColor = [0.1, 0.1, 0.4];
                    obj.Skill3Label.Visible = 'off';
                    if isvalid(obj.Skill3Icon)
                        obj.Skill3Icon.Visible = 'on';
                    end
                end
            end
        end
        function loadExplosionFrames(obj)
            % 載入Effect.png並切割成爆炸動畫幀
            try
                effectPath = fullfile(obj.basePath, 'images', 'skill', 'Effect.png');
                [effectSheet, ~, effectAlpha] = imread(effectPath);

                numColumns = 9;
                numRows = 30;
                targetRow = 4;
                numFrames = 6;

                frameWidth = floor(size(effectSheet, 2)/numColumns);
                frameHeight = floor(size(effectSheet, 1)/numRows);

                obj.ExplosionFrames = cell(1, numFrames);

                for frame = 1:numFrames
                    % 計算第四row第frame張的位置
                    startY = floor((targetRow - 1)*frameHeight) + 1;
                    startX = floor((frame - 1)*frameWidth) + 1;
                    endY = min(startY+frameHeight-1, size(effectSheet, 1));
                    endX = min(startX + frameWidth - 1, size(effectSheet, 2));

                    % 提取幀
                    frameImg = effectSheet(startY:endY, startX:endX, :);

                    % 處理alpha通道
                    if ~isempty(effectAlpha)
                        frameAlpha = effectAlpha(startY:endY, startX:endX);
                    else
                        frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                    end
                    frameImg = flipud(frameImg);
                    frameAlpha = flipud(frameAlpha);
                    obj.ExplosionFrames{frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                end

            catch ME
                warning(ME.identifier, '載入爆炸動畫失敗：%s', ME.message);
                % 創建備用的爆炸效果
                obj.ExplosionFrames = {};
                for i = 1:6
                    % 創建漸變的橙紅色圓形作為備用
                    img = ones(100, 100, 3, 'uint8');
                    intensity = (7 - i) / 6; % 逐漸減弱
                    img(:, :, 1) = uint8(255*intensity); % Red
                    img(:, :, 2) = uint8(165*intensity); % Orange
                    img(:, :, 3) = uint8(0); % Blue
                    alpha = ones(100, 100) * intensity;
                    obj.ExplosionFrames{i} = struct('Image', img, 'Alpha', alpha);
                end
            end
        end

        function useSkill3(obj)
            % --------------------------------------------
            % Step 1：本關已用次數達到上限就不執行
            if obj.Skill3UseCount >= obj.Skill3MaxUses
                return; % 已經用滿 3 次
            end

            % --------------------------------------------
            % Step 2：若在冷卻中，也不執行
            if obj.Skill3Cooldown > 0
                return;
            end

            % --------------------------------------------
            % Step 3：累加本關已用次數
            obj.Skill3UseCount = obj.Skill3UseCount + 1;
            if obj.Skill3UseCount >= obj.Skill3MaxUses
                % 已經用滿 3 次
                obj.Skill3Icon.Visible = 'off';
                obj.Skill3Label.Visible = 'off';
                obj.Skill3DescLabel.Visible='off';
            end

            % 隱藏圖示（可視需求自行保留/調整）
            if isvalid(obj.Skill3Icon)
                obj.Skill3Icon.Visible = 'off';
            end

            % 在命令列輸出 Debug 資訊
            fprintf('使用技能3：當前敵人數量：%d，第 %d 次使用\n', length(obj.Enemies), obj.Skill3UseCount);

            % --------------------------------------------
            % Step 4：在畫面中央觸發超級大爆炸動畫
            centerPos = [obj.gameWidth / 2, obj.gameHeight / 2];
            obj.createSuperExplosion(centerPos);

            % Step 5：第一次批次清除所有敵人（除了 Boss 之外都直接刪掉圖形）
            numToDestroy = length(obj.Enemies);
            obj.destroyAllEnemies(numToDestroy);

            % --------------------------------------------
            % Step 6：如果仍有殘留敵人（例如剛生成的 Boss），再次遍歷清除避免遺漏
            if ~isempty(obj.Enemies)
                fprintf('警告：技能3後仍有 %d 個敵人存在，進行二次清理\n', length(obj.Enemies));
                for i = 1:length(obj.Enemies)
                    % Boss 留下不刪
                    if isfield(obj.Enemies(i), 'Type') && strcmp(obj.Enemies(i).Type, 'boss')
                        continue;
                    end
                    try
                        if isfield(obj.Enemies(i), 'Graphic') && isgraphics(obj.Enemies(i).Graphic)
                            delete(obj.Enemies(i).Graphic);
                        end
                    catch
                        % 忽略刪除圖形時可能的錯誤
                    end
                end
                % 把殘留的非 Boss 敵人都從陣列中去除
                nonBossIdx = arrayfun(@(e) ~isfield(e, 'Type') || ~strcmp(e.Type, 'boss'), obj.Enemies);
                obj.Enemies(nonBossIdx) = [];
                fprintf('二次清理後，還剩 %d 個敵人（可能為 Boss）\n', length(obj.Enemies));
            end

            % --------------------------------------------
            % Step 7：設置冷卻時間並顯示 Label
            obj.Skill3Cooldown = obj.Skill3MaxCooldown;
            if isvalid(obj.Skill3Label)
                obj.Skill3Label.Visible = 'on';
            end
        end


        function createSuperExplosion(obj, center)
            % 創建超級大爆炸動畫
            if isempty(obj.ExplosionFrames)
                % 如果沒有載入動畫幀，創建備用效果
                fprintf('警告：爆炸動畫載入失敗，使用備用效果\n');
                return;
            end

            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 使用第一幀創建初始圖像
            firstFrame = obj.ExplosionFrames{1};
            [h, w, ~] = size(firstFrame.Image);

            % 創建爆炸圖像（放大到畫面大小）
            explosionSize = min(obj.gameWidth, obj.gameHeight) * 0.9; % 占畫面90%
            scaleFactor = explosionSize / max(h, w);

            obj.Skill3Animation = struct( ...
                'Position', center, ...
                'FrameIndex', 1, ...
                'FrameTimer', 0, ...
                'FrameInterval', 0.15, ... % 每幀持續0.15秒
                'ScaleFactor', scaleFactor, ...
                'Graphic', [], ...
                'IsActive', true ...
                );

            % 創建第一幀的圖像
            obj.updateExplosionFrame();

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end


        function updateExplosionFrame(obj)
            % 更新爆炸動畫幀
            if isempty(obj.Skill3Animation) || ~obj.Skill3Animation.IsActive
                return;
            end

            frameIndex = obj.Skill3Animation.FrameIndex;
            if frameIndex > length(obj.ExplosionFrames)
                return;
            end

            % 獲取當前幀
            frame = obj.ExplosionFrames{frameIndex};
            img = frame.Image;
            alpha = frame.Alpha;

            % 計算圖像大小和位置
            [h, w, ~] = size(img);
            scaledW = w * obj.Skill3Animation.ScaleFactor;
            scaledH = h * obj.Skill3Animation.ScaleFactor;

            centerPos = obj.Skill3Animation.Position;
            xData = [centerPos(1) - scaledW / 2, centerPos(1) + scaledW / 2];
            yData = [centerPos(2) - scaledH / 2, centerPos(2) + scaledH / 2];

            % 如果已有圖像，先刪除
            if ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                delete(obj.Skill3Animation.Graphic);
            end

            % 創建新的圖像
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            obj.Skill3Animation.Graphic = image(obj.GameAxes, xData, yData, img, ...
                'AlphaData', alpha);

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function updateSkill3Animation(obj, deltaTime)
            % 更新超級大爆炸動畫
            if isempty(obj.Skill3Animation) || ~obj.Skill3Animation.IsActive
                return;
            end

            % 更新動畫計時器
            obj.Skill3Animation.FrameTimer = obj.Skill3Animation.FrameTimer + deltaTime;

            % 檢查是否需要切換到下一幀
            if obj.Skill3Animation.FrameTimer >= obj.Skill3Animation.FrameInterval
                obj.Skill3Animation.FrameTimer = 0;
                obj.Skill3Animation.FrameIndex = obj.Skill3Animation.FrameIndex + 1;

                % 檢查動畫是否結束
                if obj.Skill3Animation.FrameIndex > length(obj.ExplosionFrames)
                    % 動畫結束，清理動畫
                    if ~isempty(obj.Skill3Animation.Graphic) && isvalid(obj.Skill3Animation.Graphic)
                        delete(obj.Skill3Animation.Graphic);
                    end
                    obj.Skill3Animation = [];

                else
                    % 更新到下一幀
                    obj.updateExplosionFrame();
                end
            end
        end


        function destroyAllEnemies(obj, maxDestroy)
            if isempty(obj.Enemies)
                return;
            end

            % 如果沒有指定最大數量，就全部消滅
            if nargin < 2
                maxDestroy = length(obj.Enemies);
            end

            % 計算實際要消滅的數量
            actualDestroy = min(maxDestroy, length(obj.Enemies));
            destroyedCount = 0;

            % 標記要刪除的敵人
            enemiesToRemove = false(1, length(obj.Enemies));

            for i = 1:length(obj.Enemies)
                if destroyedCount >= actualDestroy
                    break;
                end

                % 根據圖形類型創建不同的閃爍效果
                if isfield(obj.Enemies(i), 'Graphic') && isvalid(obj.Enemies(i).Graphic)
                    if isa(obj.Enemies(i).Graphic, 'matlab.graphics.primitive.Rectangle')
                        % Rectangle 對象 - 使用 FaceColor
                        try
                            obj.Enemies(i).Graphic.FaceColor = [1, 1, 1];
                        catch
                            % 如果設置失敗，跳過閃爍效果
                        end

                    elseif isa(obj.Enemies(i).Graphic, 'matlab.graphics.primitive.Image')
                        % Image 對象 - 使用 AlphaData 或其他效果
                        try
                            % 創建白色閃爍效果
                            originalAlpha = obj.Enemies(i).Graphic.AlphaData;
                            if ~isempty(originalAlpha)
                                % 暫時減少透明度創造閃爍效果
                                obj.Enemies(i).Graphic.AlphaData = originalAlpha * 0.5;

                                % 使用計時器恢復原始透明度
                                timer('StartDelay', 0.1, ...
                                    'TimerFcn', @(src,event) obj.restoreImageAlpha(obj.Enemies(i).Graphic, originalAlpha), ...
                                    'ExecutionMode', 'singleShot');
                            end
                        catch
                            % 如果 AlphaData 操作失敗，跳過閃爍效果
                        end

                    elseif isa(obj.Enemies(i).Graphic, 'matlab.graphics.chart.primitive.Line')
                        % Line/Plot 對象 - 改變顏色
                        try
                            obj.Enemies(i).Graphic.MarkerFaceColor = [1, 1, 1];
                            obj.Enemies(i).Graphic.MarkerEdgeColor = [1, 1, 1];
                        catch
                            % 如果設置失敗，跳過閃爍效果
                        end
                    end
                end

                % 標記為要刪除
                enemiesToRemove(i) = true;
                destroyedCount = destroyedCount + 1;
            end

            % 延遲刪除敵人（讓閃爍效果能被看到）
            timer('StartDelay', 0.2, ...
                'TimerFcn', @(src,event) obj.removeEnemies(enemiesToRemove), ...
                'ExecutionMode', 'singleShot');

            fprintf('技能3消滅了 %d 個敵人！\n', destroyedCount);
        end
        function restoreImageAlpha(obj, graphic, originalAlpha)
            % 恢復 Image 對象的原始透明度
            if isvalid(graphic)
                try
                    graphic.AlphaData = originalAlpha;
                catch
                    % 忽略錯誤
                end
            end
        end



        function loadSkill1Frames(obj)
            % 載入Effect.png第26行第1-9列
            try
                effectPath = fullfile(obj.basePath, 'images', 'skill', 'Effect.png');
                [effectSheet, ~, effectAlpha] = imread(effectPath);

                % Effect.png 是30行×9列的sheet
                numColumns = 9;
                numRows = 30;
                targetRow = 26; % 第26行
                numFrames = 9; % 第1到第9列，共九張圖片

                frameWidth = floor(size(effectSheet, 2)/numColumns);
                frameHeight = floor(size(effectSheet, 1)/numRows);

                obj.Skill1Frames = cell(1, numFrames);

                for frame = 1:numFrames
                    % 計算第26行第frame列的位置
                    startY = floor((targetRow - 1)*frameHeight) + 1;
                    startX = floor((frame - 1)*frameWidth) + 1;
                    endY = min(startY+frameHeight-1, size(effectSheet, 1));
                    endX = min(startX + frameWidth - 1, size(effectSheet, 2));

                    % 提取幀
                    frameImg = effectSheet(startY:endY, startX:endX, :);

                    % 處理alpha通道
                    if ~isempty(effectAlpha)
                        frameAlpha = effectAlpha(startY:endY, startX:endX);
                    else
                        frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                    end

                    % 翻轉圖像（與爆炸動畫保持一致）
                    frameImg = flipud(frameImg);
                    frameAlpha = flipud(frameAlpha);

                    obj.Skill1Frames{frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                end

            catch ME
                warning(ME.identifier, '載入技能1動畫失敗：%s', ME.message);
                % 創建備用的效果
                obj.Skill1Frames = {};
                for i = 1:9
                    % 創建漸變的黃色圓形作為備用
                    img = ones(100, 100, 3, 'uint8');
                    intensity = (10 - i) / 9; % 逐漸減弱
                    img(:, :, 1) = uint8(255*intensity); % Red
                    img(:, :, 2) = uint8(255*intensity); % Green (Yellow)
                    img(:, :, 3) = uint8(0); % Blue
                    alpha = ones(100, 100) * intensity;
                    obj.Skill1Frames{i} = struct('Image', img, 'Alpha', alpha);
                end
            end
        end

        function updateEnemySpawning(obj, deltaTime)
            % 更新生成計時器
            obj.EnemySpawnTimer = obj.EnemySpawnTimer + deltaTime;

            % 檢查是否該生成新敵人
            if obj.EnemySpawnTimer >= obj.EnemySpawnInterval && length(obj.Enemies) < obj.MaxEnemies
                obj.spawnNewEnemy();
                obj.EnemySpawnTimer = 0; % 重置計時器
            end
        end
        function spawnNewEnemy(obj)
            % 生成新的隨機敵人
            side = randi(4); % 1=上, 2=右, 3=下, 4=左
            margin = obj.SpawnMargin;

            switch side
                case 1 % 上方
                    spawnPos = [randi([margin, obj.gameWidth - margin]), obj.gameHeight + margin];
                case 2 % 右方
                    spawnPos = [obj.gameWidth + margin, randi([margin, obj.gameHeight - margin])];
                case 3 % 下方
                    spawnPos = [randi([margin, obj.gameWidth - margin]), -margin];
                case 4 % 左方
                    spawnPos = [-margin, randi([margin, obj.gameHeight - margin])];
            end

            % 創建新敵人
            newEnemy = struct( ...
                'Type', 'melee', ...
                'Position', spawnPos, ...
                'Health', 10, ...
                'Attack', 1, ...
                'AttackRange', 80, ...
                'AttackCooldown', 0, ...
                'SkillCooldown', 0, ...
                'SkillMaxCooldown', 0, ...
                'SkillWarning', [], ...
                'SkillWarningTimer', 0, ...
                'PoisonSlowed', false, ...
                'SlowTimer', 0, ...
                'Graphic', [], ...
                'MarkedForDeletion', false, ...
                'Direction', 1, ...
                'AnimationFrame', 1, ...
                'AnimationTimer', 0, ...
                'IsMoving', false, ...
                'IsAttacking', false, ...
                'AttackAnimationFrame', 1, ...
                'AttackAnimationTimer', 0, ...
                'AttackDirection', 1, ...
                'HasDamaged', false, ...
                'IsHurt', false, ...
                'HurtTimer', 0, ...
                'OriginalDirection', 1, ...
                'OriginalAlpha', [], ...
                'OriginalColor', [], ...
                'IsFlashing', false, ...
                'FlashTimer', [] ...
                );

            % 創建敵人圖形
            newEnemy.Graphic = obj.createEnemyGraphic(spawnPos, length(obj.Enemies)+1);

            % 添加到敵人陣列
            if isempty(obj.Enemies)
                obj.Enemies = newEnemy;
            else
                obj.Enemies(end+1) = newEnemy;
            end
        end


        function loadPlayerBulletFrames(obj)
            % 載入並預旋轉玩家子彈圖片

            try
                % 載入原始子彈圖片
                bulletPath = fullfile(obj.basePath, 'images', 'player_bullet', 'PB13.png');
                [bulletImg, ~, bulletAlpha] = imread(bulletPath);

                % 初始化預旋轉陣列
                obj.PlayerBulletFrames = cell(1, obj.NumBulletAngles);

                % 預先生成所有角度的旋轉圖片
                for i = 1:obj.NumBulletAngles
                    angle = (i - 1) * obj.BulletAngleStep; % 0, 15, 30, 45, ...

                    % 使用 imrotate 旋轉圖片
                    rotatedImg = imrotate(bulletImg, -angle, 'bicubic', 'crop');
                    rotatedAlpha = [];

                    if ~isempty(bulletAlpha)
                        rotatedAlpha = imrotate(bulletAlpha, -angle, 'bicubic', 'crop');
                    end

                    % 儲存旋轉後的圖片
                    obj.PlayerBulletFrames{i} = struct( ...
                        'Image', rotatedImg, ...
                        'Alpha', rotatedAlpha, ...
                        'Angle', angle);
                end

                fprintf('玩家子彈圖片預旋轉完成：%d 個角度\n', obj.NumBulletAngles);

            catch ME
                warning(ME.identifier, '載入玩家子彈圖片失敗：%s，使用預設圓形子彈', ME.message);
                obj.PlayerBulletFrames = {};
            end
        end


        function loadVictorySound(obj)
            try
                % 設定音效路徑
                obj.VictorySoundPath = fullfile(obj.basePath, 'sound', '統神_再來啊.mp3');

                % 檢查文件是否存在
                if exist(obj.VictorySoundPath, 'file') == 2
                    % 讀取音頻文件
                    [audioData, sampleRate] = audioread(obj.VictorySoundPath);

                    % 創建音頻播放器對象
                    obj.VictorySound = audioplayer(audioData, sampleRate);

                    fprintf('勝利音效載入成功: %s\n', obj.VictorySoundPath);
                else
                    warning('勝利音效文件不存在: %s', obj.VictorySoundPath);
                    obj.VictorySound = [];
                end

            catch ME
                obj.VictorySound = [];
            end
        end

        function playVictorySound(obj)
            try
                if ~isempty(obj.VictorySound) && isvalid(obj.VictorySound)

                    % 播放音效
                    play(obj.VictorySound);

                    fprintf('正在播放勝利音效\n');
                else
                    fprintf('勝利音效未載入，無法播放\n');
                end
            catch ME
                warning(ME.identifier, '播放勝利音效時發生錯誤：%s', ME.message);
            end
        end

        function useBossSkill2(obj, bossIndex)
            % BOSS技能2：毒藥水攻擊
            bossPos = obj.Enemies(bossIndex).Position;
            targetPos = obj.Player.Position;

            fprintf('BOSS使用毒藥水技能，目標位置：[%.1f, %.1f]\n', targetPos(1), targetPos(2));

            % BOSS投擲毒藥水
            obj.throwBossPoisonBottle(bossPos, targetPos);
        end


        function throwBossPoisonBottle(obj, startPos, targetPos)
            % BOSS投擲毒藥水
            direction = targetPos - startPos;
            distance = norm(direction);

            if distance == 0
                return;
            end

            normalizedDirection = direction / distance;

            % 創建BOSS毒藥水投擲物
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            % 創建投擲物圖形（紫色圓點，區別於玩家的綠色）
            projectileGraphic = plot(obj.GameAxes, startPos(1), startPos(2), 'o', ...
                'MarkerSize', 15, ...
                'MarkerFaceColor', [0.8, 0, 0.8], ... % 紫色
                'MarkerEdgeColor', [0.6, 0, 0.6], ...
                'LineWidth', 3);

            % 創建投擲物數據
            newProjectile = struct( ...
                'Position', startPos, ...
                'TargetPos', targetPos, ...
                'Speed', 6, ... % 比玩家稍慢
                'Graphic', projectileGraphic, ...
                'Direction', normalizedDirection ...
                );

            % 添加到BOSS投擲物陣列
            obj.BossPoisonProjectiles{end+1} = newProjectile;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end
        end

        function createBossPoisonArea(obj, center)
            % 創建BOSS毒區域效果
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            radius = 100; % BOSS毒區域半徑比玩家大

            % 創建紫色圓形毒區域（區別於玩家的綠色）
            theta = linspace(0, 2*pi, 50);
            x = center(1) + radius * cos(theta);
            y = center(2) + radius * sin(theta);

            % 創建填充圓形
            poisonArea = fill(obj.GameAxes, x, y, [0.8, 0, 0.8], ... % 紫色
                'FaceAlpha', 0.5, ...
                'EdgeColor', [0.6, 0, 0.6], ...
                'LineWidth', 3);

            % 創建BOSS毒區域數據
            newPoisonArea = struct( ...
                'Position', center, ...
                'Radius', radius, ...
                'Graphic', poisonArea, ...
                'Timer', 4.0, ... % 持續4秒（比玩家久）
                'DamageTimer', 1, ... % 傷害計時器
                'DamageInterval', 1.0 ... % 每秒造成傷害
                );

            % 添加到BOSS毒區域陣列
            obj.BossPoisonAreas{end+1} = newPoisonArea;

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end

            fprintf('BOSS毒區域創建在位置：[%.1f, %.1f]\n', center(1), center(2));
        end


        function updateBossPoisonProjectiles(obj, deltaTime)
            % 更新BOSS毒藥水投擲物
            projectilesToRemove = [];

            for i = 1:length(obj.BossPoisonProjectiles)
                projectile = obj.BossPoisonProjectiles{i};

                % 移動投擲物
                projectile.Position = projectile.Position + projectile.Direction * projectile.Speed;

                % 更新圖形位置
                if isvalid(projectile.Graphic)
                    projectile.Graphic.XData = projectile.Position(1);
                    projectile.Graphic.YData = projectile.Position(2);
                end

                % 檢查是否到達目標位置
                distance = norm(projectile.Position-projectile.TargetPos);
                if distance <= 15 % 到達目標位置
                    % 創建BOSS毒區域
                    obj.createBossPoisonArea(projectile.TargetPos);

                    % 移除投擲物
                    if isvalid(projectile.Graphic)
                        delete(projectile.Graphic);
                    end
                    projectilesToRemove(end+1) = i;
                end

                % 更新投擲物數據
                obj.BossPoisonProjectiles{i} = projectile;
            end

            % 移除已到達的投擲物
            obj.BossPoisonProjectiles(projectilesToRemove) = [];
        end

        function updateBossPoisonAreas(obj, deltaTime)
            % 更新BOSS毒區域
            areasToRemove = [];

            for i = 1:length(obj.BossPoisonAreas)
                area = obj.BossPoisonAreas{i};

                % 更新計時器
                area.Timer = area.Timer - deltaTime;
                area.DamageTimer = area.DamageTimer + deltaTime;

                % 檢查是否需要造成傷害
                if area.DamageTimer >= area.DamageInterval
                    obj.applyBossPoisonDamage(area);
                    area.DamageTimer = 0;
                end

                % 檢查是否過期
                if area.Timer <= 0
                    % 移除毒區域
                    if isvalid(area.Graphic)
                        delete(area.Graphic);
                    end
                    areasToRemove(end+1) = i;
                else
                    % 更新透明度（漸漸消失效果）
                    if isvalid(area.Graphic)
                        alpha = area.Timer / 4.0; % 原始持續時間
                        area.Graphic.FaceAlpha = alpha * 0.5;
                    end
                end

                % 更新區域數據
                obj.BossPoisonAreas{i} = area;
            end

            % 移除過期的區域
            obj.BossPoisonAreas(areasToRemove) = [];
        end

        function applyBossPoisonDamage(obj, area)
            % BOSS毒區域對玩家造成傷害和減速
            distance = norm(obj.Player.Position-area.Position);

            % 如果玩家在毒區域內
            if distance <= area.Radius
                % 造成傷害（BOSS毒傷害更高）
                bossPoisonDamage = 3; % 固定傷害值
                obj.Player.Health = obj.Player.Health - bossPoisonDamage;

                % 播放受擊音效
                try
                    if ~isempty(obj.HitSEPlayer) && isvalid(obj.HitSEPlayer)
                        if isplaying(obj.HitSEPlayer)
                            stop(obj.HitSEPlayer);
                            obj.HitSEPlayer.CurrentSample = 1;
                        end
                        play(obj.HitSEPlayer);
                    end
                catch
                end

                % 減速效果（讓玩家移動速度變慢）
                % 注意：需要在updatePlayerMovement中實現減速邏輯
                obj.Player.PoisonSlowed = true;
                obj.Player.SlowTimer = 1.5; % 減速效果持續1.5秒

                fprintf('玩家受到BOSS毒傷害：%d，剩餘血量：%d\n', bossPoisonDamage, obj.Player.Health);

                % 檢查玩家是否死亡
                if obj.Player.Health <= 0
                    obj.showGameOverScreen();
                end
            end
        end


        function startBoss3ExplosionWarning(obj)
            % 開始全螢幕爆炸警告
            obj.Boss3WarningActive = true;

            % 創建全螢幕紅色警告背景
            wasHeld = ishold(obj.GameAxes);
            hold(obj.GameAxes, 'on');

            obj.Boss3ExplosionWarning = rectangle(obj.GameAxes, ...
                'Position', [0, 0, obj.gameWidth, obj.gameHeight], ...
                'FaceColor', [1, 0, 0], ...
                'FaceAlpha', 0.4, ...
                'EdgeColor', [1, 0, 0], ...
                'LineWidth', 8);

            if ~wasHeld
                hold(obj.GameAxes, 'off');
            end

            obj.Boss3WarningActive = true;
            fprintf('BOSS3爆炸警告開始！\n');
        end

        function updateBoss3Warning(obj, timeLeft)
            % 更新警告顯示
            if ~obj.Boss3WarningActive
                return;
            end

            % 閃爍效果（每0.3秒切換一次）
            if ~isempty(obj.Boss3ExplosionWarning) && isvalid(obj.Boss3ExplosionWarning)
                flashCycle = mod(timeLeft, 0.6);
                if flashCycle < 0.3
                    obj.Boss3ExplosionWarning.FaceAlpha = 0.6;
                else
                    obj.Boss3ExplosionWarning.FaceAlpha = 0.2;
                end
            end
        end

        function executeFinalBossExplosion(obj)
            % 清理警告效果
            obj.cleanupBoss3Warning();

            % 在畫面中央創建超大爆炸動畫
            centerPos = [obj.gameWidth / 2, obj.gameHeight / 2];

            % 創建全螢幕爆炸效果
            if ~isempty(obj.ExplosionFrames)
                wasHeld = ishold(obj.GameAxes);
                hold(obj.GameAxes, 'on');

                % 創建超大爆炸圖形
                explosionSize = 500; % 超大爆炸覆蓋全螢幕

                firstFrame = obj.ExplosionFrames{1};
                obj.BossExplosionEffect = image(obj.GameAxes, ...
                    [centerPos(1) - explosionSize, centerPos(1) + explosionSize], ...
                    [centerPos(2) - explosionSize, centerPos(2) + explosionSize], ...
                    firstFrame.Image, 'AlphaData', firstFrame.Alpha);

                if ~wasHeld
                    hold(obj.GameAxes, 'off');
                end

                % 啟動爆炸動畫
                obj.startFinalExplosionAnimation();
            end

            % 播放受擊音效
            try
                if ~isempty(obj.HitSEPlayer) && isvalid(obj.HitSEPlayer)
                    if isplaying(obj.HitSEPlayer)
                        stop(obj.HitSEPlayer);
                        obj.HitSEPlayer.CurrentSample = 1;
                    end
                    play(obj.HitSEPlayer);
                end
            catch
            end

            fprintf('BOSS致命爆炸！玩家死亡！\n');

        end

        function startFinalExplosionAnimation(obj)
            % 啟動致命爆炸動畫播放
            if isempty(obj.ExplosionFrames)
                return;
            end

            % 創建動畫計時器
            explosionTimer = timer('Period', 0.08, ...
                'TasksToExecute', length(obj.ExplosionFrames), ...
                'ExecutionMode', 'fixedRate');

            % 動畫計數器
            frameCounter = 1;

            % 設置計時器回調函數
            explosionTimer.TimerFcn = @(src, event) obj.updateFinalExplosionFrame(frameCounter);
            explosionTimer.StopFcn = @(src, event) obj.cleanupFinalExplosion(src);

            % 啟動動畫
            start(explosionTimer);
        end

        function updateFinalExplosionFrame(obj, frameIndex)
            % 更新致命爆炸動畫幀
            persistent currentFrame;
            if isempty(currentFrame)
                currentFrame = 1;
            end

            if ~isempty(obj.BossExplosionEffect) && isvalid(obj.BossExplosionEffect) && ...
                    currentFrame <= length(obj.ExplosionFrames)

                frame = obj.ExplosionFrames{currentFrame};
                obj.BossExplosionEffect.CData = frame.Image;
                obj.BossExplosionEffect.AlphaData = frame.Alpha;

                currentFrame = currentFrame + 1;
            end
        end

        function cleanupFinalExplosion(obj, timerObj)
            % 直接讓玩家死亡
            obj.Player.Health = 0;
            % 更新UI顯示
            if ~isempty(obj.HealthLabel) && isvalid(obj.HealthLabel)
                obj.HealthLabel.Text = sprintf('生命值: %d', obj.Player.Health);
            end
            % 清理致命爆炸動畫
            try
                % 停止並刪除計時器
                stop(timerObj);
                delete(timerObj);

                % 清理爆炸圖形
                if ~isempty(obj.BossExplosionEffect) && isvalid(obj.BossExplosionEffect)
                    delete(obj.BossExplosionEffect);
                    obj.BossExplosionEffect = [];
                end

                fprintf('致命爆炸動畫完成\n');

            catch
                % 忽略清理錯誤
            end
        end

        function cleanupBoss3Warning(obj)
            % 清理BOSS3爆炸警告
            try
                if ~isempty(obj.Boss3ExplosionWarning) && isvalid(obj.Boss3ExplosionWarning)
                    delete(obj.Boss3ExplosionWarning);
                end
                obj.Boss3ExplosionWarning = [];

                obj.Boss3WarningActive = false;
            catch
                % 忽略清理錯誤
            end
        end

        function loadEnemyAnimations(obj)

            try
                enemyImagePath = fullfile(obj.basePath, 'images', 'enemy', 'Slime1_Walk_full.png');

                [enemySheet, ~, enemyAlpha] = imread(enemyImagePath);

                % 4行8列：下、上、左、右 × 8幀
                numDirections = 4;
                numFrames = 8;

                enemyFrameHeight = floor(size(enemySheet, 1)/4);
                enemyFrameWidth = floor(size(enemySheet, 2)/8);

                obj.EnemyRunFrames = cell(numDirections, numFrames);

                % 載入每個方向的每一幀
                for dir = 1:numDirections
                    for frame = 1:numFrames
                        % 計算當前幀位置
                        startY = floor((dir - 1)*enemyFrameHeight) + 1;
                        startX = floor((frame - 1)*enemyFrameWidth) + 1;
                        endY = floor(startY+enemyFrameHeight-1);
                        endX = floor(startX + enemyFrameWidth - 1);

                        % 範圍安全檢查
                        endY = min(endY, size(enemySheet, 1));
                        endX = min(endX, size(enemySheet, 2));

                        % 提取幀
                        frameImg = enemySheet(startY:endY, startX:endX, :);
                        if ~isempty(enemyAlpha)
                            frameAlpha = enemyAlpha(startY:endY, startX:endX);
                        else
                            frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                        end

                        % 翻轉圖像（Y軸翻轉以符合MATLAB座標系）
                        frameImg = flipud(frameImg);
                        frameAlpha = flipud(frameAlpha);

                        obj.EnemyRunFrames{dir, frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                    end
                end

                fprintf('敵人動畫載入成功：%d方向 x %d幀\n', numDirections, numFrames);

            catch ME
                warning(ME.identifier, '載入敵人動畫失敗：%s', ME.message);
                obj.EnemyRunFrames = {};
            end
        end
        function direction = getEnemyMoveDirection(obj, normalizedDirection)
            % 根據移動向量確定動畫方向
            % 1=下, 2=上, 3=左, 4=右
            if abs(normalizedDirection(2)) > abs(normalizedDirection(1))
                if normalizedDirection(2) > 0
                    direction = 2; % 上
                else
                    direction = 1; % 下
                end
            else
                if normalizedDirection(1) > 0
                    direction = 4; % 右
                else
                    direction = 3; % 左
                end
            end
        end

        function updateEnemyAnimation(obj, enemyIndex)
            % 更新敵人動畫
            if isempty(obj.EnemyRunFrames) || enemyIndex > length(obj.Enemies)
                return;
            end

            % 檢查是否正在受傷
            if obj.Enemies(enemyIndex).IsHurt
                obj.Enemies(enemyIndex).HurtTimer = obj.Enemies(enemyIndex).HurtTimer - 0.016;

                % 受傷時間結束，恢復正常動畫
                if obj.Enemies(enemyIndex).HurtTimer <= 0
                    obj.Enemies(enemyIndex).IsHurt = false;
                    obj.Enemies(enemyIndex).HurtTimer = 0;

                    % 重置動畫幀到第1幀
                    obj.Enemies(enemyIndex).AnimationFrame = 1;
                    obj.Enemies(enemyIndex).AnimationTimer = 0;

                    % 恢復原始方向
                    obj.Enemies(enemyIndex).Direction = obj.Enemies(enemyIndex).OriginalDirection;

                    % 立即更新圖形到移動動畫的第一幀
                    if isvalid(obj.Enemies(enemyIndex).Graphic) && isa(obj.Enemies(enemyIndex).Graphic, 'matlab.graphics.primitive.Image')
                        frameData = obj.EnemyRunFrames{obj.Enemies(enemyIndex).Direction, 1};
                        obj.Enemies(enemyIndex).Graphic.CData = frameData.Image;
                        obj.Enemies(enemyIndex).Graphic.AlphaData = frameData.Alpha;
                    end
                end

                % 受傷期間不更新移動動畫
                obj.updateEnemyPosition(enemyIndex);
                return;
            end

            % 正常的移動動畫更新邏輯
            obj.Enemies(enemyIndex).AnimationTimer = obj.Enemies(enemyIndex).AnimationTimer + 0.016;

            % 檢查是否需要更新動畫幀
            if obj.Enemies(enemyIndex).AnimationTimer >= obj.EnemyAnimationSpeed
                if obj.Enemies(enemyIndex).IsMoving
                    % 更新動畫幀
                    obj.Enemies(enemyIndex).AnimationFrame = mod(obj.Enemies(enemyIndex).AnimationFrame, 8) + 1;
                end

                % 只有當圖形是 Image 類型且有動畫幀時才更新圖形
                if isvalid(obj.Enemies(enemyIndex).Graphic) && ...
                        isa(obj.Enemies(enemyIndex).Graphic, 'matlab.graphics.primitive.Image') && ...
                        ~strcmp(obj.Enemies(enemyIndex).Type, 'boss')

                    % 確保動畫方向和幀數在有效範圍內
                    if obj.Enemies(enemyIndex).Direction <= size(obj.EnemyRunFrames, 1) && ...
                            obj.Enemies(enemyIndex).AnimationFrame <= size(obj.EnemyRunFrames, 2)

                        frameData = obj.EnemyRunFrames{obj.Enemies(enemyIndex).Direction, obj.Enemies(enemyIndex).AnimationFrame};
                        obj.Enemies(enemyIndex).Graphic.CData = frameData.Image;
                        obj.Enemies(enemyIndex).Graphic.AlphaData = frameData.Alpha;
                    end
                end

                % 重置動畫計時器
                obj.Enemies(enemyIndex).AnimationTimer = 0;
            end

            % 更新位置
            obj.updateEnemyPosition(enemyIndex);
        end


        function updateEnemyPosition(obj, enemyIndex)
            if enemyIndex > length(obj.Enemies) || ~isvalid(obj.Enemies(enemyIndex).Graphic)
                return;
            end

            pos = obj.Enemies(enemyIndex).Position;
            graphic = obj.Enemies(enemyIndex).Graphic;

            % 根據圖形類型進行不同的位置更新
            if isa(graphic, 'matlab.graphics.primitive.Image')
                % Image 類型 - 使用 XData 和 YData
                xData = graphic.XData;
                yData = graphic.YData;
                width = xData(2) - xData(1);
                height = yData(2) - yData(1);
                graphic.XData = [pos(1) - width / 2, pos(1) + width / 2];
                graphic.YData = [pos(2) - height / 2, pos(2) + height / 2];

            elseif isa(graphic, 'matlab.graphics.primitive.Rectangle')
                % Rectangle 類型 - 使用 Position 屬性
                if strcmp(obj.Enemies(enemyIndex).Type, 'boss')
                    graphic.Position = [pos(1) - 30, pos(2) - 30, 60, 60];
                else
                    graphic.Position = [pos(1) - 15, pos(2) - 15, 30, 30];
                end

            elseif isa(graphic, 'matlab.graphics.chart.primitive.Line')
                % Line/Plot 類型（圓形標記）- 使用 XData 和 YData
                graphic.XData = pos(1);
                graphic.YData = pos(2);

            else
                try
                    if isprop(graphic, 'XData') && isprop(graphic, 'YData')
                        graphic.XData = pos(1);
                        graphic.YData = pos(2);
                    elseif isprop(graphic, 'Position')
                        graphic.Position = [pos(1) - 15, pos(2) - 15, 30, 30];
                    end
                catch
                    % 如果都失敗了，就跳過
                    warning('無法更新敵人 %d 的位置，圖形類型：%s', enemyIndex, class(graphic));
                end
            end
        end

        function loadEnemyAttackAnimations(obj)
            % 載入敵人攻擊動畫
            enemyAttackPath = fullfile(obj.basePath, 'images', 'enemy', 'Slime1_Attack_full.png');

            if ~exist(enemyAttackPath, 'file')
                warning('找不到敵人攻擊動畫圖片：%s', enemyAttackPath);
                obj.EnemyAttackFrames = {};
                return;
            end

            try
                [attackSheet, ~, attackAlpha] = imread(enemyAttackPath);

                % 4行10列：下、上、左、右 × 10幀
                numDirections = 4;
                numFrames = 10;

                attackFrameHeight = floor(size(attackSheet, 1)/4);
                attackFrameWidth = floor(size(attackSheet, 2)/10);

                obj.EnemyAttackFrames = cell(numDirections, numFrames);

                % 載入每個方向的每一幀
                for dir = 1:numDirections
                    for frame = 1:numFrames
                        % 計算當前幀位置
                        startY = floor((dir - 1)*attackFrameHeight) + 1;
                        startX = floor((frame - 1)*attackFrameWidth) + 1;
                        endY = floor(startY+attackFrameHeight-1);
                        endX = floor(startX + attackFrameWidth - 1);

                        % 範圍安全檢查
                        endY = min(endY, size(attackSheet, 1));
                        endX = min(endX, size(attackSheet, 2));

                        % 提取幀
                        frameImg = attackSheet(startY:endY, startX:endX, :);
                        if ~isempty(attackAlpha)
                            frameAlpha = attackAlpha(startY:endY, startX:endX);
                        else
                            frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                        end

                        % 翻轉圖像（Y軸翻轉以符合MATLAB座標系）
                        frameImg = flipud(frameImg);
                        frameAlpha = flipud(frameAlpha);

                        obj.EnemyAttackFrames{dir, frame} = struct('Image', frameImg, 'Alpha', frameAlpha);
                    end
                end

                fprintf('敵人攻擊動畫載入成功：%d方向 x %d幀\n', numDirections, numFrames);

            catch ME
                warning(ME.identifier, '載入敵人攻擊動畫失敗：%s', ME.message);
                obj.EnemyAttackFrames = {};
            end
        end
        function updateEnemyAttackAnimation(obj, enemyIndex)
            % 更新敵人攻擊動畫
            if isempty(obj.EnemyAttackFrames) || enemyIndex > length(obj.Enemies)
                % 沒有攻擊動畫時，結束攻擊狀態
                obj.Enemies(enemyIndex).IsAttacking = false;
                return;
            end

            % 更新攻擊動畫計時器
            obj.Enemies(enemyIndex).AttackAnimationTimer = obj.Enemies(enemyIndex).AttackAnimationTimer + 0.016;

            % 檢查是否需要更新動畫幀
            if obj.Enemies(enemyIndex).AttackAnimationTimer >= obj.EnemyAttackAnimationSpeed
                % 在第8幀時造成傷害
                if obj.Enemies(enemyIndex).AttackAnimationFrame == 8 && ~obj.Enemies(enemyIndex).HasDamaged
                    obj.Enemies(enemyIndex).HasDamaged = true;
                    obj.executeEnemyAttackDamage(enemyIndex);
                end

                % 更新攻擊動畫幀
                obj.Enemies(enemyIndex).AttackAnimationFrame = obj.Enemies(enemyIndex).AttackAnimationFrame + 1;

                % 檢查攻擊動畫是否播放完畢
                if obj.Enemies(enemyIndex).AttackAnimationFrame > 10 % 攻擊動畫有10幀
                    % 攻擊動畫結束
                    obj.Enemies(enemyIndex).IsAttacking = false;
                    obj.Enemies(enemyIndex).AttackAnimationFrame = 1;
                    obj.Enemies(enemyIndex).HasDamaged = false;
                    fprintf('敵人 %d 攻擊動畫結束\n', enemyIndex);
                else
                    % 更新圖形
                    if isvalid(obj.Enemies(enemyIndex).Graphic) && isa(obj.Enemies(enemyIndex).Graphic, 'matlab.graphics.primitive.Image')
                        frameData = obj.EnemyAttackFrames{obj.Enemies(enemyIndex).AttackDirection, obj.Enemies(enemyIndex).AttackAnimationFrame};
                        obj.Enemies(enemyIndex).Graphic.CData = frameData.Image;
                        obj.Enemies(enemyIndex).Graphic.AlphaData = frameData.Alpha;
                    end
                end

                % 重置攻擊動畫計時器
                obj.Enemies(enemyIndex).AttackAnimationTimer = 0;
            end

            % 更新位置（保持在原地）
            obj.updateEnemyPosition(enemyIndex);
        end

        function executeEnemyAttackDamage(obj, enemyIndex)
            % 執行敵人攻擊傷害
            if enemyIndex > length(obj.Enemies)
                return;
            end

            % 對玩家造成傷害（不管距離）
            obj.Player.Health = obj.Player.Health - obj.Enemies(enemyIndex).Attack;

            % 播放受擊音效
            try
                if ~isempty(obj.HitSEPlayer) && isvalid(obj.HitSEPlayer)
                    if isplaying(obj.HitSEPlayer)
                        stop(obj.HitSEPlayer);
                        obj.HitSEPlayer.CurrentSample = 1;
                    end
                    play(obj.HitSEPlayer);
                end
            catch
                % 若載入失敗或其他狀況，就靜默忽略
            end

            fprintf('敵人 %d 在第8幀對玩家造成 %d 點傷害！玩家剩餘血量：%d\n', ...
                enemyIndex, obj.Enemies(enemyIndex).Attack, obj.Player.Health);
        end

        function loadEnemyHurtAnimations(obj)
            % 載入敵人受傷動畫
            enemyHurtPath = fullfile(obj.basePath, 'images', 'enemy', 'Slime1_Hurt_full.png');

            if ~exist(enemyHurtPath, 'file')
                warning('找不到敵人受傷動畫圖片：%s', enemyHurtPath);
                obj.EnemyHurtFrames = {};
                return;
            end

            try
                [hurtSheet, ~, hurtAlpha] = imread(enemyHurtPath);

                % 4行5列，使用第3列的圖片
                numDirections = 4; % 下、上、左、右
                targetColumn = 3; % 使用第3列

                hurtFrameHeight = floor(size(hurtSheet, 1)/4);
                hurtFrameWidth = floor(size(hurtSheet, 2)/5);

                obj.EnemyHurtFrames = cell(numDirections, 1);

                % 載入每個方向第3列的圖片
                for dir = 1:numDirections
                    % 計算第3列的位置
                    startY = floor((dir - 1)*hurtFrameHeight) + 1;
                    startX = floor((targetColumn - 1)*hurtFrameWidth) + 1;
                    endY = floor(startY+hurtFrameHeight-1);
                    endX = floor(startX + hurtFrameWidth - 1);

                    % 範圍安全檢查
                    endY = min(endY, size(hurtSheet, 1));
                    endX = min(endX, size(hurtSheet, 2));

                    % 提取幀
                    frameImg = hurtSheet(startY:endY, startX:endX, :);
                    if ~isempty(hurtAlpha)
                        frameAlpha = hurtAlpha(startY:endY, startX:endX);
                    else
                        frameAlpha = ones(size(frameImg, 1), size(frameImg, 2));
                    end

                    % 翻轉圖像
                    frameImg = flipud(frameImg);
                    frameAlpha = flipud(frameAlpha);

                    obj.EnemyHurtFrames{dir} = struct('Image', frameImg, 'Alpha', frameAlpha);
                end

                fprintf('敵人受傷動畫載入成功：%d方向\n', numDirections);

            catch ME
                warning(ME.identifier, '載入敵人受傷動畫失敗：%s', ME.message);
                obj.EnemyHurtFrames = {};
            end
        end


    end
end

% 更新位置輔助函數：支援 rectangle 與 image 物件
function updatePosition(graphicObj, pos)
if ~isvalid(graphicObj)
    warning('嘗試更新無效的圖形對象');
    return;
end

switch class(graphicObj)
    case 'matlab.graphics.primitive.Rectangle'
        % rectangle 用 Position 屬性
        rectPos = graphicObj.Position;
        w = rectPos(3);
        h = rectPos(4);
        graphicObj.Position = [pos(1) - w / 2, pos(2) - h / 2, w, h];

    case 'matlab.graphics.primitive.Image'
        % image 用 XData, YData 來定位
        xd = get(graphicObj, 'XData');
        yd = get(graphicObj, 'YData');
        w = abs(xd(2)-xd(1));
        h = abs(yd(2)-yd(1));
        newX = [pos(1) - w / 2, pos(1) + w / 2];
        newY = [pos(2) - h / 2, pos(2) + h / 2];
        set(graphicObj, 'XData', newX, 'YData', newY);

    otherwise
        % 普通敵人使用圓形標記
        graphicObj.XData = pos(1);
        graphicObj.YData = pos(2);

        return;
end
end
