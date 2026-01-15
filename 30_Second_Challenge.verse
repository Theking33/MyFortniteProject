using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/UI }
using { /Fortnite.com/Characters }
using { /Verse.org/Colors }
using { /Verse.org/Random }

# إحصائيات اللاعب خلال الجولة
player_stats := struct:
    Score : int = 0
    CorrectAnswers : int = 0
    WrongAnswers : int = 0
    TimedOut : int = 0

# البيانات الدائمة للاعبين
player_permanent_data := struct<persistable>:
    TotalMatches : int = 0
    TotalWins : int = 0
    TotalLosses : int = 0

var PlayerDataStore : weak_map(player, player_permanent_data) = map{}

# مستويات الصعوبة للبوت
difficulty_level := enum{Easy, Medium, Hard}

challenge_30_manager := class(creative_device):

    var PlayerRoundStats : [player]player_stats = map{}
    var CurrentRoundQuestions : []question_database = array{}
    var CurrentDifficulty : difficulty_level = difficulty_level.Easy

    # --- الأجهزة الخارجية ---
    @editable GameStartTrigger : trigger_device = trigger_device{}
    @editable PlayerCounter : player_counter_device = player_counter_device{}
    @editable LeaderboardDevice : leaderboard_device = leaderboard_device{}
    @editable Question_DB : question_database = question_database{}

    # --- إعدادات اللعبة ---
    @editable SecondsPerQuestion : int = 15 
    @editable PenaltyValue : int = 1 
    @editable DebugMode : logic = false
    @editable RoundDuration : float = 30.0

    # --- المؤثرات الصوتية ---
    @editable TimerTickSound : audio_player_device = audio_player_device{} 
    @editable SuccessSound : audio_player_device = audio_player_device{}   
    @editable FailureSound : audio_player_device = audio_player_device{}
    @editable NewTurnSound : audio_player_device = audio_player_device{}

    # --- متغيرات الحالة الداخلية ---
    var CurrentPlayers : []player = array{}
    var ShuffledQuestions : []question_struct = array{} 
    var PlayerScores : [player]int = map{}
    var PlayersStatsMap : [player]player_stats = map{}
    var AIStats : player_stats = player_stats{}

    var AIScore : int = 0 
    var IsPlayingWithAI : logic = false
    var CurrentAIDifficulty : difficulty_level = difficulty_level.Medium
    var CurrentQuestionIndex : int = 0 
    var IsGameActive : logic = false
    var TurnPlayerIndex : int = 0 
    var RemainingTime : int = 0
    var IsWaitingForAnswer : logic = false
    var StatusCanvas : weak_map(player, canvas) = map{}

    # مراجع واجهة المستخدم
    var MainCanvas : [player]?canvas = map{}
    var ModeSelectionCanvas : [player]?canvas = map{}
    var FeedbackCanvas : [player]?canvas = map{}
    var FinalCanvas : [player]?canvas = map{}
    var TimerTextBlock : [player]?text_block = map{} 
    var IntroCanvas : [player]?canvas = map{}
    var FlashCanvas : [player]?canvas = map{}


    # مراجع لنصوص الواجهة لتحديثها برمجياً
    var ScoreTextBlock : [player]text_block = map{}



    WaitMessage<localizes><public> : message = "بانتظار لاعب آخر للانضمام..."
    BusyMessage<localizes><public> : message = "هذا الجهاز مشغول حالياً.. هناك جولة نشطة"

    # تعريف الرسائل المترجمة
    Msg_Main<localizes>(T:string) : message = "{T}"
    Msg_Stats<localizes>(Label:string, Value:int) : message = "{Label}: {Value}"


    StringToMessage<localizes><public>(S : string) : message = "{S}"


    AddScoreToPlayer(Player : player, Amount : int) : void =
        if (CurrentStats := PlayerRoundStats[Player]):
            NewScore := CurrentStats.Score + Amount
            # تحديث البيانات في الـ Map
             set PlayerRoundStats[Player] = player_stats{
                Score := NewScore,
                CorrectAnswers := CurrentStats.CorrectAnswers,
                WrongAnswers := CurrentStats.WrongAnswers,
                TimedOut := CurrentStats.TimedOut
            }

            # تحديث النص في واجهة اللاعب فوراً إذا كان موجوداً
            if (ScoreText := ScoreTextBlock[Player]):
                ScoreText.SetText(StringToMessage("النقاط: {NewScore}"))




    OnBegin<override>()<suspends> : void =
        GameStartTrigger.TriggeredEvent.Subscribe(OnTriggerActivated)





    CreateStatusUI(Text : message, Color : color) : canvas =
        NewCanvas := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.4}, Maximum := vector2{X := 0.5, Y := 0.4}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := text_block:
                        DefaultText := Text
                        DefaultTextColor := Color
                        DefaultShadowColor := NamedColors.Black
                        DefaultShadowOffset := option{vector2{X := 2.0, Y := 2.0}}
                        
        return NewCanvas

    # 3. دالة لإظهار الرسالة للاعب معين
    ShowStatusMessage(P : player, Msg : message, DisplayTime : float) : void =
        spawn:
            HandleStatusMessageAsync(P, Msg, DisplayTime)

    HandleStatusMessageAsync(P : player, Msg : message, DisplayTime : float)<suspends> : void =
        if (PlayerUI := GetPlayerUI[P]):
            # إزالة أي رسالة سابقة إن وجدت
            if (OldCanvas := StatusCanvas[P]):
                PlayerUI.RemoveWidget(OldCanvas)
            
            # إنشاء وعرض الرسالة الجديدة
            MyCanvas := CreateStatusUI(Msg, NamedColors.White)
            if (set StatusCanvas[P] = MyCanvas):
                PlayerUI.AddWidget(MyCanvas)
                
                # الانتظار ثم المسح
                Sleep(DisplayTime)
                
                # التأكد أننا نمسح نفس الواجهة التي أضفناها (وليس واجهة جديدة ظهرت بعدها)
                if (CurrentCanvas := StatusCanvas[P], CurrentCanvas = MyCanvas):
                    PlayerUI.RemoveWidget(MyCanvas)

    # --- مثال على الاستخدام في دوال الربط (Triggers) ---

    # عند دخول لاعب لجهاز التعداد

        # تسلسل بداية المباراة مع النص الاحترافي
    StartMatchSequence(InPlayer:player)<suspends> : void =

          for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P]):
                # تهيئة الإحصائيات
                if (set PlayerRoundStats[P] = player_stats{}) {}
                
                # استدعاء الدالة وتخزين النتيجة في متغير مؤقت من نوع canvas
                NewIntro := ShowIntroSplash(P)
                
                # الآن نقوم بالتعيين داخل الـ option
                if (set IntroCanvas[P] = option{NewIntro}):
                    PlayerUI.AddWidget(NewIntro, player_ui_slot{InputMode := ui_input_mode.All})

        FreezePlayers()
        ShowIntroSplash(InPlayer)
        Sleep(3.0) # مدة عرض نص "تحدي الثلاثين"
        ClearIntroSplash(InPlayer)
        UnfreezePlayers()
        ShowModeSelectionUI(InPlayer)

   

    # --- واجهة "تحدي الثلاثين" الاحترافية ---
    ShowIntroSplash(InPlayer:player) : void =
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P]):
                # نقوم بتعريف المتغير وتحديد نوعه كـ canvas بشكل صريح هنا
                NewIntro : canvas = canvas:
                    Slots := array:
                        # خلفية سوداء شفافة
                        canvas_slot:
                            Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
                            Widget := color_block{DefaultColor := NamedColors.Black, DefaultOpacity := 0.6}
                        
                        # النص الرئيسي "تحدي الـ 30 ثانية"
                        canvas_slot:
                            Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.4}, Maximum := vector2{X := 0.5, Y := 0.4}}
                            Alignment := vector2{X := 0.5, Y := 0.5}
                            Widget := text_block:
                                DefaultText := Msg_Main("تحدي الـ 30 ثانية")
                                DefaultTextColor := NamedColors.Gold
                        
                        # خط زخرفي تحت النص
                        canvas_slot:
                            Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.45}, Maximum := vector2{X := 0.5, Y := 0.45}}
                            Alignment := vector2{X := 0.5, Y := 0.5}
                            Widget := color_block{DefaultColor := NamedColors.Gold, DefaultDesiredSize := vector2{X := 400.0, Y := 4.0}}

                        # نص فرعي تحفيزي
                        canvas_slot:
                            Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.55}, Maximum := vector2{X := 0.5, Y := 0.55}}
                            Alignment := vector2{X := 0.5, Y := 0.5}
                            Widget := text_block:
                                DefaultText := Msg_Main("استعد للإجابة بسرعة!")
                                DefaultTextColor := NamedColors.White

                # الآن نقوم بتخزينها في الخريطة (Map) وإضافتها للشاشة
                if (set IntroCanvas[P] = option{NewIntro}):
                    PlayerUI.AddWidget(NewIntro, player_ui_slot{InputMode := ui_input_mode.All})

    ClearIntroSplash(InPlayer:player) : void =
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P], C := IntroCanvas[P]?):
                PlayerUI.RemoveWidget(C)
                if (set IntroCanvas[P] = false) {}

    # --- منطق التفعيل المعدل (يضمن جلب جميع اللاعبين) ---
    OnTriggerActivated(MaybeAgent : ?agent) : void =

        if (not IsGameActive?):
            # جلب اللاعبين من جهاز العداد بدلاً من الاعتماد على من ضغط الزر فقط
            AgentsInside := PlayerCounter.GetCountedAgents()
            set CurrentPlayers = array{}
            for (A : AgentsInside, P := player[A]):
                set CurrentPlayers += array{P}
            
            # إذا وجد لاعبين، نبدأ التسلسل
            if (CurrentPlayers.Length > 0):
                if (FirstPlayer := CurrentPlayers[0]):
                    spawn { StartMatchSequence(FirstPlayer) }


    #OnPlayerAddedToCounter(Agent : agent) : void =

     #   if (P := player[Agent]):
            # فحص إذا كانت اللعبة بدأت فعلاً أو لسه بنجمع لاعبين
      #      if (IsGameActive = false):
       #         # إذا كان الجهاز يحتاج 2 والآن فيه 1 فقط
        #        if (PlayerCounter.GetCount() < 2):
         #           ShowStatusMessage(P,WaitMessage, 5.0)
          #      if (PlayerCounter.GetCount() = 2):
           #         ShowStatusMessage(P,BusyMessage, 5.0)




    ShowSimpleOverlay(P : player, Text : message) : void =

        if (PlayerUI := GetPlayerUI[P]):
            # هنا تضع كود الـ Canvas الخاص بك لعرض النص
            Print("Displaying Message to Player")

    # --- واجهة اختيار نمط اللعب ---
    # الوظيفة: بناء وإظهار قائمة (PvP أو Bot).
    # ماذا تفعل؟: تصمم واجهة الـ  (الأزرار والرسائل) وتضيفها لشاشة اللاعب. كما تقوم ببرمجة الأزرار لتعرف ماذا تفعل عند الضغط عليها  
    ShowModeSelectionUI(InPlayer : player) : void =  
        
        BtnAI := button_loud{DefaultText := Msg_Main("🤖 اللعب ضد البوت")}
        BtnPvP := button_loud{DefaultText := Msg_Main("⚔️ اللعب ضد لاعب")}
        BtnExit := button_regular{DefaultText := Msg_Main("❌ خروج")}

        BtnAI.OnClick().Subscribe(OnSelectAIMenu)
        BtnPvP.OnClick().Subscribe(OnSelectPvP)
        BtnExit.OnClick().Subscribe(OnExitClicked)

        NewCanvas := canvas:
            Slots := array:
                canvas_slot: 
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := color_block{DefaultColor := color{R := 0.01, G := 0.02, B := 0.05}, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}}
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := text_block{DefaultText := Msg_Main("تحدي الثلاثين -\n اختر النمط"), DefaultTextColor := NamedColors.Gold}
                                Padding := margin{Bottom := 50.0}
                            stack_box_slot:
                                Widget := stack_box:
                                    Orientation := orientation.Horizontal
                                    Slots := array:
                                        stack_box_slot{Widget := BtnAI, Padding := margin{Right := 20.0}}
                                        stack_box_slot{Widget := BtnPvP, Padding := margin{Left := 20.0}}
                            stack_box_slot:
                                HorizontalAlignment := horizontal_alignment.Center
                                Widget := BtnExit
        
        if (PlayerUI := GetPlayerUI[InPlayer]):
            if (set ModeSelectionCanvas[InPlayer] = option{NewCanvas}):
                PlayerUI.AddWidget(NewCanvas, player_ui_slot{InputMode := ui_input_mode.All})
                # --- عند اختيارك للبوت اختر مستوى البوت---
    OnSelectAIMenu(WM : widget_message) : void =
        RemoveSelectionUI(WM.Player)
        
        BtnEasy := button_loud{DefaultText := Msg_Main("🟢 سهل")}
        BtnMed := button_loud{DefaultText := Msg_Main("🟡 متوسط")}
        BtnHard := button_loud{DefaultText := Msg_Main("🔴 صعب")}

        BtnEasy.OnClick().Subscribe(OnEasySelected)
        BtnMed.OnClick().Subscribe(OnMedSelected)
        BtnHard.OnClick().Subscribe(OnHardSelected)

        DiffCanvas := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := text_block{DefaultText := Msg_Main("اختر مستوى ذكاء البوت"), DefaultTextColor := NamedColors.White}
                                Padding := margin{Bottom := 30.0}
                            stack_box_slot:
                                 Widget := BtnEasy
                                 Padding := margin{Bottom := 30.0}
                            stack_box_slot:
                                 Widget := BtnMed
                                 Padding := margin{Bottom := 30.0}
                            stack_box_slot:
                                 Widget := BtnHard
                                 Padding := margin{Bottom := 30.0}
        
        if (PlayerUI := GetPlayerUI[WM.Player]):
            if (set ModeSelectionCanvas[WM.Player] = option{DiffCanvas}):
                PlayerUI.AddWidget(DiffCanvas, player_ui_slot{InputMode := ui_input_mode.All})

    OnEasySelected(WM : widget_message) : void = StartAIWithDifficulty(WM.Player, difficulty_level.Easy)
    OnMedSelected(WM : widget_message) : void = StartAIWithDifficulty(WM.Player, difficulty_level.Medium)
    OnHardSelected(WM : widget_message) : void = StartAIWithDifficulty(WM.Player, difficulty_level.Hard)

    # --- ابدا اللعب مع البوت  --- 

    StartAIWithDifficulty(InPlayer : player, Level : difficulty_level) : void =
        RemoveSelectionUI(InPlayer)
        set IsPlayingWithAI = true
        set CurrentAIDifficulty = Level
        set CurrentPlayers = array{InPlayer}
        StartGameLogic()

    OnExitClicked(WM : widget_message) : void = 
        RemoveSelectionUI(WM.Player)


        # --- معالجة اختيار اللاعب للنمط ---

    OnSelectPvP(WM : widget_message) : void =
        RemoveSelectionUI(WM.Player)
        if (DebugMode?): # اختبار يمكنك ان تتجاوز وتلعب مع نفسك فقط للتجربة
            set IsPlayingWithAI = false
            set CurrentPlayers = array{WM.Player, WM.Player}
            StartGameLogic()
        else:
            Player := WM.Player
            # فحص عدد اللاعبين الموجودين في الـ Player Counter
            CurrentPlayerCount := PlayerCounter.GetCount()
            
           
            

            if (CurrentPlayerCount < 2):


                    # إذا كان اللاعب وحده، تظهر رسالة الانتظار ولا تبدأ اللعبة
                Print("لاعب واحد فقط.. إظهار رسالة الانتظار")
                ShowWaitFeedback(Player)
            else:


                    # إذا وجد لاعبين، تبدأ المباراة
                Print("تم العثور على خصم.. بدء المباراة")
                    # هنا تضع كود إزالة الواجهة وبدء المباراة
                StartGameLogic()

    # وظيفة إظهار الرسالة
    ShowWaitFeedback(InPlayer : player) : void =
        if (PlayerUI := GetPlayerUI[InPlayer]):
            # إذا كانت هناك رسالة ظاهرة حالياً، لا تكررها
            if (not FeedbackCanvas[InPlayer]?):
                NewFeedback := canvas:
                    Slots := array:
                        canvas_slot:
                            Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.7}, Maximum := vector2{X := 0.5, Y := 0.7}}
                            Alignment := vector2{X := 0.5, Y := 0.5}
                            Widget := text_block{DefaultText := WaitMessage, DefaultTextColor := NamedColors.Red}
                
                if (set FeedbackCanvas[InPlayer] = option{NewFeedback}):
                    PlayerUI.AddWidget(NewFeedback)
                    # استدعاء الـ spawn بطريقة أبسط لتجنب أخطاء الـ Unsupported argument
                    spawn:
                        RemoveFeedbackAfterDelay(InPlayer, 10.0)

    # وظيفة التعليق (Suspends) لمسح الرسالة بعد وقت
    RemoveFeedbackAfterDelay(InPlayer : player, Delay : float) <suspends> : void =
        Sleep(Delay)
        if (PlayerUI := GetPlayerUI[InPlayer]):
            if (CurrentFeedback := FeedbackCanvas[InPlayer]?):
                PlayerUI.RemoveWidget(CurrentFeedback)
                # تفريغ الخريطة للسماح بإظهار الرسالة مرة أخرى لاحقاً
                var TempMap : [player]?canvas = FeedbackCanvas
                if (set TempMap[InPlayer] = false) {}
                set FeedbackCanvas = TempMap


    RemoveFeedbackLater(UI : player_ui, W : widget) <suspends> : void =
        Sleep(2.0)
        UI.RemoveWidget(W)

              
            CountedAgents := PlayerCounter.GetCountedAgents()
            var ValidPlayers : []player = array{}
            for (A : CountedAgents):
                if (P := player[A]):
                    set ValidPlayers += array{P}
            
            if (ValidPlayers.Length >= 2):
                set IsPlayingWithAI = false
                if (P1 := ValidPlayers[0], P2 := ValidPlayers[1]):
                    set CurrentPlayers = array{P1, P2}
                    StartGameLogic()

    RemoveSelectionUI(InPlayer : player) : void =
        if (PlayerUI := GetPlayerUI[InPlayer]):
            if (CurrentCanvas := ModeSelectionCanvas[InPlayer]?):
                PlayerUI.RemoveWidget(CurrentCanvas)
                if (set ModeSelectionCanvas[InPlayer] = false) {}


     # توضع هذه الدالة في قسم (وظائف مساعدة) في نهاية الكود
    FlashScreen(P: player, Color: color) : void =
        if (PlayerUI := GetPlayerUI[P]):
            # إنشاء صورة تغطي كامل الشاشة بلون شفاف (Opacity 0.3)
            FlashWidget := color_block:
                DefaultColor := Color
                DefaultOpacity := 0.3
                DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}

            NewFlashCanvas := canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Widget := FlashWidget

            # إزالة أي وميض سابق
            if (OldCanvas := FlashCanvas[P]?):
                PlayerUI.RemoveWidget(OldCanvas)

            # إضافة الوميض الجديد
            PlayerUI.AddWidget(NewFlashCanvas)
            if (set FlashCanvas[P] = option{NewFlashCanvas}) {}

            # مؤقت لإزالة الوميض بعد 0.2 ثانية
            spawn { RemoveFlash(P, 0.2) }

    # دالة فرعية لإزالة الوميض
    RemoveFlash(P: player, Delay: float)<suspends> : void =
        Sleep(Delay)
        if (PlayerUI := GetPlayerUI[P], C := FlashCanvas[P]?):
            PlayerUI.RemoveWidget(C)
            if (set FlashCanvas[P] = false) {}

    # --- منطق بدء الجولة ---
    StartGameLogic() : void =
        FreezePlayers()
        TempShuffled := Shuffle(Question_DB.AllQuestions)
        var MaxQuestions : int = 30
        if (TempShuffled.Length < 30):
            set MaxQuestions = TempShuffled.Length
        
        set ShuffledQuestions = for (I := 0..MaxQuestions-1, Q := TempShuffled[I]) do Q
        set CurrentQuestionIndex = 0
        set IsGameActive = true
        set TurnPlayerIndex = 0 
        
        for (P : CurrentPlayers):
            if (set PlayerScores[P] = 0) {}
            if (set PlayersStatsMap[P] = player_stats{}) {}
            
            if (CurrentData := PlayerDataStore[P]):
                if (set PlayerDataStore[P] = player_permanent_data{
                    TotalMatches := CurrentData.TotalMatches + 1,
                    TotalWins := CurrentData.TotalWins,
                    TotalLosses := CurrentData.TotalLosses
                }) {}
            else:
                if (set PlayerDataStore[P] = player_permanent_data{TotalMatches := 1}) {}
        
        set AIScore = 0
        set AIStats = player_stats{}
        StartNewRound()

    StartNewRound() : void =
        ClearAllPossibleUI()
        if (CurrentQuestionIndex < ShuffledQuestions.Length):
            set IsWaitingForAnswer = true
            set RemainingTime = SecondsPerQuestion
            CreateMainUI()
            
            spawn:
                StartTimer()
            
            if (IsPlayingWithAI?, TurnPlayerIndex = 1):
                spawn:
                    AISimulationLogic()
        else:
            UnfreezePlayers()
            DetermineWinner()

    # --- واجهة اللعبة خلال السؤال ---
    CreateMainUI() : void =
        if (Q := ShuffledQuestions[CurrentQuestionIndex]):
            var ScoreText : string = ""
            var LocalNum : int = 1
            if (Val := Floor[1.0 * CurrentQuestionIndex / 2.0]):
                set LocalNum = Val + 1

            if (IsPlayingWithAI?):
                if (P := CurrentPlayers[0], PScore := PlayerScores[P]):
                    set ScoreText = " أنت: {PScore}  |   البوت: {AIScore}"
            else:
                if (P1 := CurrentPlayers[0], P2 := CurrentPlayers[1], S1 := PlayerScores[P1], S2 := PlayerScores[P2]):
                    set ScoreText = "P1: {S1}  |  P2: {S2}"

            var StatusText : string = ""
            if (IsPlayingWithAI?):
                set StatusText = if (TurnPlayerIndex = 0) then "دَوْرُكَ" else "🤖 البوت يفكر..."
            else:
                set StatusText = if (TurnPlayerIndex = 0) then "دَوْرُ اللاعب 1" else "دَوْرُ اللاعب 2"
            
            for (Idx -> P : CurrentPlayers):
                if (Idx = TurnPlayerIndex):
                    NewTurnSound.Play(P)

                NewTimerBlock := text_block{
                    DefaultText := Msg_Main("السؤال {LocalNum} / 15\n {RemainingTime}s - {StatusText}\n\n{Q.QuestionText}"),
                    DefaultTextColor := NamedColors.White
                }
                
                if (set TimerTextBlock[P] = option{NewTimerBlock}) {}

                BaseSlots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}, DefaultOpacity := 0.4}
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := overlay:
                            Slots := array:
                                overlay_slot:
                                    Widget := color_block{DefaultColor := color{R := 0.01, G := 0.03, B := 0.1}, DefaultDesiredSize := vector2{X := 1100.0, Y := 800.0}, DefaultOpacity := 0.9}
                                overlay_slot:
                                    VerticalAlignment := vertical_alignment.Top
                                    Widget := color_block{DefaultColor := NamedColors.Gold, DefaultDesiredSize := vector2{X := 1100.0, Y := 10.0}}
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.15}, Maximum := vector2{X := 0.5, Y := 0.15}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := text_block{DefaultText := Msg_Main(ScoreText), DefaultTextColor := NamedColors.Cyan}
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.4}, Maximum := vector2{X := 0.5, Y := 0.4}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := NewTimerBlock

                var FinalSlots : []canvas_slot = BaseSlots

                if (Idx = TurnPlayerIndex and not (IsPlayingWithAI? and Idx = 1)):
                    BtnA := button_loud{DefaultText := Msg_Main(" " + Q.OptionA)}
                    BtnB := button_loud{DefaultText := Msg_Main(" " + Q.OptionB)}
                    BtnC := button_loud{DefaultText := Msg_Main(" " + Q.OptionC)}
                    BtnD := button_loud{DefaultText := Msg_Main(" " + Q.OptionD)}
                    
                    BtnA.OnClick().Subscribe(OnBtnAClicked)
                    BtnB.OnClick().Subscribe(OnBtnBClicked)
                    BtnC.OnClick().Subscribe(OnBtnCClicked)
                    BtnD.OnClick().Subscribe(OnBtnDClicked)

                    ButtonContainer := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := stack_box:
                                    Orientation := orientation.Horizontal
                                    Slots := array:
                                        stack_box_slot:
                                            Widget := BtnA
                                            Padding := margin{Right := 15.0}
                                        stack_box_slot:
                                            Widget := BtnB
                                            Padding := margin{Left := 15.0}
                                Padding := margin{Bottom := 20.0}
                            stack_box_slot:
                                Widget := stack_box:
                                    Orientation := orientation.Horizontal
                                    Slots := array:
                                        stack_box_slot:
                                            Widget := BtnC
                                            Padding := margin{Right := 15.0}
                                        stack_box_slot:
                                            Widget := BtnD
                                            Padding := margin{Left := 15.0}

                    ButtonSlot := canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.72}, Maximum := vector2{X := 0.5, Y := 0.72}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := ButtonContainer
                    
                    set FinalSlots += array{ButtonSlot}
                else:
                    WaitingText := text_block{DefaultText := Msg_Main("⏳ الخيارات ستظهر عندما يحين دورك..."), DefaultTextColor := NamedColors.Gray}
                    WaitingSlot := canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.72}, Maximum := vector2{X := 0.5, Y := 0.5}}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        Widget := WaitingText
                    set FinalSlots += array{WaitingSlot}

                FinalPlayerCanvas := canvas{ Slots := FinalSlots }

                if (PlayerUI := GetPlayerUI[P]):
                    if (set MainCanvas[P] = option{FinalPlayerCanvas}):
                        InputMode := if (Idx = TurnPlayerIndex and not (IsPlayingWithAI? and Idx = 1)) then ui_input_mode.All else ui_input_mode.None
                        PlayerUI.AddWidget(FinalPlayerCanvas, player_ui_slot{InputMode := InputMode})

    OnBtnAClicked(WM : widget_message) : void = OnAnswerClicked(0, WM.Player)
    OnBtnBClicked(WM : widget_message) : void = OnAnswerClicked(1, WM.Player)
    OnBtnCClicked(WM : widget_message) : void = OnAnswerClicked(2, WM.Player)
    OnBtnDClicked(WM : widget_message) : void = OnAnswerClicked(3, WM.Player)

    # --- منطق العداد الزمني ---
    StartTimer()<suspends> : void =
        loop:
            if (not IsWaitingForAnswer? or not IsGameActive?):
                 break
            
            if (RemainingTime <= 0):
                set IsWaitingForAnswer = false
                if (TurnPlayerIndex = 0):
                    if (P := CurrentPlayers[0], S := PlayerScores[P], Stats := PlayersStatsMap[P]):
                        NewScore := if (S - PenaltyValue < 0) then 0 else S - PenaltyValue
                        if (set PlayerScores[P] = NewScore) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers, WrongAnswers := Stats.WrongAnswers, TimedOut := Stats.TimedOut + 1}) {}
                else:
                    if (IsPlayingWithAI?):
                        set AIScore = if (AIScore - PenaltyValue < 0) then 0 else AIScore - PenaltyValue
                        set AIStats = player_stats{CorrectAnswers := AIStats.CorrectAnswers, WrongAnswers := AIStats.WrongAnswers, TimedOut := AIStats.TimedOut + 1}
                    else if (P := CurrentPlayers[1], S := PlayerScores[P], Stats := PlayersStatsMap[P]):
                        NewScore := if (S - PenaltyValue < 0) then 0 else S - PenaltyValue
                        if (set PlayerScores[P] = NewScore) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers, WrongAnswers := Stats.WrongAnswers, TimedOut := Stats.TimedOut + 1}) {}

                spawn:
                     ShowFeedbackAndContinue(" انتهى الوقت! (تم خصم نقطة)", false)
                break
            
            if (RemainingTime <= 10):
                if (IsPlayingWithAI?, Human := CurrentPlayers[0]):
                     TimerTickSound.Play(Human)
                else if (P := CurrentPlayers[TurnPlayerIndex]):
                     TimerTickSound.Play(P)
            
            if (Q := ShuffledQuestions[CurrentQuestionIndex]):
                var LocalNum : int = 1
                if (Val := Floor[1.0 * CurrentQuestionIndex / 2.0]):
                     set LocalNum = Val + 1
                
                var Status : string = ""
                if (IsPlayingWithAI?):
                    set Status = if (TurnPlayerIndex = 0) then "دَوْرُكَ" else "🤖 البوت يفكر..."
                else:
                    set Status = if (TurnPlayerIndex = 0) then "دَوْرُ اللاعب 1" else "دَوْرُ اللاعب 2"

                for (P : CurrentPlayers):
                    if (TB := TimerTextBlock[P]?):
                        TB.SetText(Msg_Main("السؤال {LocalNum} / 15\n {RemainingTime}s - {Status}\n\n{Q.QuestionText}"))
            
            Sleep(1.0)
            set RemainingTime -= 1

    # --- محاكاة ذكاء البوت ---
    AISimulationLogic()<suspends> : void =
        ThinkTime := if (CurrentAIDifficulty = difficulty_level.Hard) then GetRandomFloat(2.0, 4.0) else GetRandomFloat(4.0, 7.0)
        Sleep(ThinkTime)
        
        if (IsGameActive?, IsWaitingForAnswer?, TurnPlayerIndex = 1, HumanPlayer := CurrentPlayers[0], Q := ShuffledQuestions[CurrentQuestionIndex]):
            ErrorChance := case(CurrentAIDifficulty):
                difficulty_level.Easy => 0.65
                difficulty_level.Medium => 0.30
                difficulty_level.Hard => 0.05
            
            FinalChoice := if (GetRandomFloat(0.0, 1.0) < ErrorChance) then GetRandomInt(0, 3) else Q.CorrectIndex
            OnAnswerClicked(FinalChoice, HumanPlayer)

   
    # --- معالجة الإجابة ---
    OnAnswerClicked(SentIndex : int,InPlayer : player) : void =

    
        if (IsGameActive?, IsWaitingForAnswer?, Q := ShuffledQuestions[CurrentQuestionIndex]):
            set IsWaitingForAnswer = false
            IsCorrect := if (SentIndex = Q.CorrectIndex) then true else false
            
            if (IsCorrect?): 
                
                SuccessSound.Play(InPlayer)
                FlashScreen(InPlayer, NamedColors.Green)
            else: 
               
                FailureSound.Play(InPlayer)
                FlashScreen(InPlayer, NamedColors.Red)
            
            var FeedbackMsg : string = ""
            if (TurnPlayerIndex = 0):
                if (P := CurrentPlayers[0], S := PlayerScores[P], Stats := PlayersStatsMap[P]):
                    if (IsCorrect?):
                        set FeedbackMsg = "✅ مذهل! إجابة صحيحة"
                        if (set PlayerScores[P] = S + Q.PointsValue) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers + 1, WrongAnswers := Stats.WrongAnswers, TimedOut := Stats.TimedOut}) {}
                        LeaderboardDevice.HandleStatIncreased(option{InPlayer})
                    else:
                        set FeedbackMsg = "❌ للأسف، إجابة خاطئة"
                        NewScore := if (S - PenaltyValue < 0) then 0 else S - PenaltyValue
                        if (set PlayerScores[P] = NewScore) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers, WrongAnswers := Stats.WrongAnswers + 1, TimedOut := Stats.TimedOut}) {}
            else:
                Opp := if (IsPlayingWithAI?) then "البوت" else "الخصم"
                if (IsCorrect?):
                    set FeedbackMsg = "✅ {Opp} أجاب صح"
                    if (IsPlayingWithAI?):
                        set AIScore += Q.PointsValue
                        set AIStats = player_stats{CorrectAnswers := AIStats.CorrectAnswers + 1, WrongAnswers := AIStats.WrongAnswers, TimedOut := AIStats.TimedOut}
                    else if (P := CurrentPlayers[1], S := PlayerScores[P], Stats := PlayersStatsMap[P]):
                        if (set PlayerScores[P] = S + Q.PointsValue) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers + 1, WrongAnswers := Stats.WrongAnswers, TimedOut := Stats.TimedOut}) {}
                        LeaderboardDevice.HandleStatIncreased(option{P})
                else:
                    set FeedbackMsg = "❌ {Opp} أخطأ الإجابة"
                    if (IsPlayingWithAI?):
                        set AIScore = if (AIScore - PenaltyValue < 0) then 0 else AIScore - PenaltyValue
                        set AIStats = player_stats{CorrectAnswers := AIStats.CorrectAnswers, WrongAnswers := AIStats.WrongAnswers + 1, TimedOut := AIStats.TimedOut}
                    else if (P := CurrentPlayers[1], S := PlayerScores[P], Stats := PlayersStatsMap[P]):
                        NewScore := if (S - PenaltyValue < 0) then 0 else S - PenaltyValue
                        if (set PlayerScores[P] = NewScore) {}
                        if (set PlayersStatsMap[P] = player_stats{CorrectAnswers := Stats.CorrectAnswers, WrongAnswers := Stats.WrongAnswers + 1, TimedOut := Stats.TimedOut}) {}
            
            spawn: 
                ShowFeedbackAndContinue(FeedbackMsg, IsCorrect)

    ShowFeedbackAndContinue(Msg : string, Correct : logic)<suspends> : void =
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P], C := MainCanvas[P]?): 
                PlayerUI.RemoveWidget(C)
        for (P : CurrentPlayers):
             if (set MainCanvas[P] = false) {}

        ShowFeedbackUI(Msg, Correct)
        Sleep(2.5) 
        
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P], C := FeedbackCanvas[P]?):
                 PlayerUI.RemoveWidget(C)
        for (P : CurrentPlayers): 
            if (set FeedbackCanvas[P] = false) {}

        set CurrentQuestionIndex += 1
        set TurnPlayerIndex = 1 - TurnPlayerIndex
        StartNewRound()

    ShowFeedbackUI(Msg : string, Correct : logic) : void =
        MsgColor := if (Correct?) then NamedColors.Green else NamedColors.Red
        NewFeedback := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := overlay:
                        Slots := array:
                            overlay_slot:
                                Widget := color_block{DefaultColor := NamedColors.Black, DefaultDesiredSize := vector2{X := 800.0, Y := 200.0}, DefaultOpacity := 0.9}
                            overlay_slot:
                                HorizontalAlignment := horizontal_alignment.Center
                                VerticalAlignment := vertical_alignment.Center
                                Widget := text_block{DefaultText := Msg_Main(Msg), DefaultTextColor := MsgColor}
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P]): 
                if (set FeedbackCanvas[P] = option{NewFeedback}):
                     PlayerUI.AddWidget(NewFeedback)

    # --- تحديد الفائز وعرض النتائج ---
    DetermineWinner() : void =
        set IsGameActive = false
        ClearAllPossibleUI()
        var WinnerTitle : string = ""
        var P1_Stats : player_stats = player_stats{}
        var P2_Stats : player_stats = player_stats{}
        var P1_Name : string = "أنت"
        var P2_Name : string = "الخصم"

        if (IsPlayingWithAI?):
            if (P := CurrentPlayers[0], S := PlayerScores[P], PS := PlayersStatsMap[P]):
                set P1_Stats = PS
                set P2_Stats = AIStats
                set P2_Name = "البوت"
                if (S > AIScore):
                     set WinnerTitle = "🏆 مبروك الفوز الساحق! 🏆"
                     UpdatePersistence(P, true)
                else if (AIScore > S):
                     set WinnerTitle = "🤖 للأسف، البوت انتصر! 🤖"
                     UpdatePersistence(P, false)
                else: 
                    set WinnerTitle = "🤝 تعادل أسطوري! 🤝"
        else:
            if (P1 := CurrentPlayers[0], P2 := CurrentPlayers[1], S1 := PlayerScores[P1], S2 := PlayerScores[P2]):
                set P1_Stats = PlayersStatsMap[P1] or player_stats{}
                set P2_Stats = PlayersStatsMap[P2] or player_stats{}
                set P1_Name = "اللاعب 1"
                set P2_Name = "اللاعب 2"
                if (S1 > S2):
                     set WinnerTitle = "🏆 فوز مستحق للاعب 1! 🏆"
                     UpdatePersistence(P1, true)
                     UpdatePersistence(P2, false)
                else if (S2 > S1):
                     set WinnerTitle = "🏆 فوز مستحق للاعب 2! 🏆"
                     UpdatePersistence(P1, false)
                     UpdatePersistence(P2, true)
                else:
                     set WinnerTitle = "🤝 تعادل مشرف للطرفين! 🤝"
    
        spawn: 
            ShowFinalResultUI(WinnerTitle, P1_Name, P1_Stats, P2_Name, P2_Stats)

    UpdatePersistence(P : player, Won : logic) : void =
        if (CurrentData := PlayerDataStore[P]):
            NewWins := if (Won?) then CurrentData.TotalWins + 1 else CurrentData.TotalWins
            NewLosses := if (not Won?) then CurrentData.TotalLosses + 1 else CurrentData.TotalLosses
            if (set PlayerDataStore[P] = player_permanent_data{
                TotalMatches := CurrentData.TotalMatches,
                TotalWins := NewWins,
                TotalLosses := NewLosses
            }) {}

    ShowFinalResultUI(Title : string, N1 : string, S1 : player_stats, N2 : string, S2 : player_stats)<suspends> : void =
        var PD1 : player_permanent_data = player_permanent_data{}
        var PD2 : player_permanent_data = player_permanent_data{}

        if (P1 := CurrentPlayers[0], Data := PlayerDataStore[P1]):
            set PD1 = Data
        
        # إذا لم يكن هناك ذكاء اصطناعي، نحضر بيانات اللاعب الثاني
        if (not IsPlayingWithAI?):
            if (P2 := CurrentPlayers[1], Data := PlayerDataStore[P2]):
                set PD2 = Data

        NewFinalCanvas := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := color_block{DefaultColor := color{R := 0.0, G := 0.0, B := 0.0}, DefaultDesiredSize := vector2{X := 1920.0, Y := 1080.0}, DefaultOpacity := 0.08}
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := overlay:
                        Slots := array:
                            overlay_slot:
                                Widget := color_block{DefaultColor := color{R := 0.01, G := 0.03, B := 0.1}, DefaultDesiredSize := vector2{X := 1100.0, Y := 800.0}, DefaultOpacity := 1.0}
                            overlay_slot:
                                VerticalAlignment := vertical_alignment.Top
                                Widget := color_block{DefaultColor := NamedColors.Gold, DefaultDesiredSize := vector2{X := 1100.0, Y := 10.0}}
                               

                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.35}, Maximum := vector2{X := 0.5, Y := 0.35}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := text_block{DefaultText := Msg_Main(Title), DefaultTextColor := NamedColors.Gold}
                
                # إحصائيات اللاعب الأول
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.35, Y := 0.55}, Maximum := vector2{X := 0.35, Y := 0.55}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Main(N1), DefaultTextColor := NamedColors.Cyan}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("✅ صحيح", S1.CorrectAnswers), DefaultTextColor := NamedColors.Green}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("❌ خاطئ", S1.WrongAnswers), DefaultTextColor := NamedColors.Red}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("إجمالي المباريات", PD1.TotalMatches), DefaultTextColor := NamedColors.White}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("إجمالي الفوز", PD1.TotalWins), DefaultTextColor := NamedColors.Yellow}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("انتهاء الوقت", S1.TimedOut), DefaultTextColor := NamedColors.Gray}
                
                # إحصائيات اللاعب الثاني / البوت
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := 0.65, Y := 0.55}, Maximum := vector2{X := 0.65, Y := 0.55}}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Main(N2), DefaultTextColor := NamedColors.Orange}
                            stack_box_slot: 
                                Widget := text_block{DefaultText := Msg_Stats("✅ صحيح", S2.CorrectAnswers), DefaultTextColor := NamedColors.Green}
                            stack_box_slot: 
                                Widget := text_block{DefaultText := Msg_Stats("❌ خاطئ", S2.WrongAnswers), DefaultTextColor := NamedColors.Red}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("إجمالي المباريات", PD2.TotalMatches), DefaultTextColor := NamedColors.White}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("إجمالي الفوز", PD2.TotalWins), DefaultTextColor := NamedColors.Yellow}
                            stack_box_slot:
                                 Widget := text_block{DefaultText := Msg_Stats("انتهاء الوقت", S2.TimedOut), DefaultTextColor := NamedColors.Gray}


        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P]): 
                if (set FinalCanvas[P] = option{NewFinalCanvas}):
                    PlayerUI.AddWidget(NewFinalCanvas, player_ui_slot{InputMode := ui_input_mode.All})
        
        Sleep(15.0) 
        ClearAllPossibleUI()
        UnfreezePlayers() 

    # --- وظائف مساعدة ---
    FreezePlayers() : void =
        for (P : CurrentPlayers):
            if (FC := P.GetFortCharacter[]):
                FC.PutInStasis(stasis_args{AllowFalling := true, AllowEmotes := false})

    UnfreezePlayers() : void =
        for (P : CurrentPlayers):
            if (FC := P.GetFortCharacter[]):
                FC.ReleaseFromStasis()

    #--- ماذا تفعل؟ : تتأكد من حذف أي واجهة مستخدم  من شاشة اللاعب قبل الانتقال للمرحلة التالية لضمان عدم تراكم النصوص فوق بعضها --- 
    ClearAllPossibleUI() : void =
        for (P : CurrentPlayers):
            if (PlayerUI := GetPlayerUI[P]):
                if (C := MainCanvas[P]?):
                     PlayerUI.RemoveWidget(C)
                if (C := FeedbackCanvas[P]?):
                     PlayerUI.RemoveWidget(C)
                if (C := FinalCanvas[P]?):
                     PlayerUI.RemoveWidget(C)
                if (C := ModeSelectionCanvas[P]?): 
                    PlayerUI.RemoveWidget(C)
                if (C := IntroCanvas[P]?):
                     PlayerUI.RemoveWidget(C)
                if (C := FlashCanvas[P]?):  # --- مسح الوميض عند انتهاء اللعبه ---
                    PlayerUI.RemoveWidget(C)
        
        for (P : CurrentPlayers):
            if (set MainCanvas[P] = false) {}
            if (set FeedbackCanvas[P] = false) {}
            if (set FinalCanvas[P] = false) {}
            if (set TimerTextBlock[P] = false) {}
            if (set IntroCanvas[P] = false) {}
