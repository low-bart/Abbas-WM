function NMTP_Outer_Training1


%The first training in a series of protocols for a 6 port
%stimulus-focused working memory task. Training 1 will familiarize the
%subject with poking to dispense reward as well as holding for reward.

global BpodSystem


S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SampleReward = 1; %μl
    S.GUI.SampleHoldTime = 0.01;
    S.GUI.DelayReward = 1; %μl
    S.GUI.DelayHoldTime = 0.01;
    S.GUI.ChoiceReward = 5; %μl
    S.GUI.ChoiceHoldTime = 0.01;
    S.GUI.ITI = 15; % How long the mouse must poke in the center to activate the goal port
end

%% Define trials

MaxTrials = 600;
TrialTypes = zeros(1, 600);
for fill = 1:150
    block = randperm(4);
    TrialTypes(fill*4-3:fill*4) = block;
end
BpodSystem.Data.TrialTypes = []; 

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 340 1000 400],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.TrialTypeOutcomePlot = axes('Position', [.075 .3 .89 .6]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'init',TrialTypes);
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

TimeTaken = zeros(1, 1000);
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    if S.GUI.SampleHoldTime < 0.2
        S.GUI.SampleHoldTime = S.GUI.SampleHoldTime + .02;
    end
    if S.GUI.DelayHoldTime < 0.5
        S.GUI.DelayHoldTime = S.GUI.DelayHoldTime + .02;
    end
    if S.GUI.ChoiceHoldTime < 0.2
        S.GUI.ChoiceHoldTime = S.GUI.ChoiceHoldTime + .02;
    end
    
    S = BpodParameterGUI('sync', S);
 
    switch TrialTypes(currentTrial)
        case 1
            SampleLight = {'PWM1', 50}; WhichSampleIn = {'Port1In'}; WhichSampleOut = {'Port1Out'};
            SampleValve = {'Valve1', 1}; SampleValveTime = GetValveTimes(S.GUI.SampleReward, 1);
            ChoiceLight = {'PWM3', 50}; WhichChoiceIn = {'Port3In'}; WhichChoiceOut = {'Port3Out'};
            ChoiceValve = {'Valve3', 1}; ChoiceValveTime = GetValveTimes(S.GUI.ChoiceReward, 3);
        case 2
            SampleLight = {'PWM1', 50}; WhichSampleIn = {'Port1In'}; WhichSampleOut = {'Port1Out'};
            SampleValve = {'Valve1', 1}; SampleValveTime = GetValveTimes(S.GUI.SampleReward, 1);
            ChoiceLight = {'PWM5', 50}; WhichChoiceIn = {'Port5In'}; WhichChoiceOut = {'Port5Out'};
            ChoiceValve = {'Valve5', 1}; ChoiceValveTime = GetValveTimes(S.GUI.ChoiceReward, 5);
        case 3
            SampleLight = {'PWM5', 50}; WhichSampleIn = {'Port5In'}; WhichSampleOut = {'Port5Out'};
            SampleValve = {'Valve5', 1}; SampleValveTime = GetValveTimes(S.GUI.SampleReward, 5);
            ChoiceLight = {'PWM1', 50}; WhichChoiceIn = {'Port1In'}; WhichChoiceOut = {'Port1Out'};
            ChoiceValve = {'Valve1', 1}; ChoiceValveTime = GetValveTimes(S.GUI.ChoiceReward, 1);
        case 4
            SampleLight = {'PWM5', 50}; WhichSampleIn = {'Port5In'}; WhichSampleOut = {'Port5Out'};
            SampleValve = {'Valve5', 1}; SampleValveTime = GetValveTimes(S.GUI.SampleReward, 5);
            ChoiceLight = {'PWM3', 50}; WhichChoiceIn = {'Port3In'}; WhichChoiceOut = {'Port3Out'};
            ChoiceValve = {'Valve3', 1}; ChoiceValveTime = GetValveTimes(S.GUI.ChoiceReward, 3);
    end
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    %Waiting for first choice, sample start (needs valve calibration)
    
    sma = AddState(sma, 'Name', 'ITI', 'Timer', S.GUI.ITI,...
        'StateChangeConditions', {'Tup', 'WaitForSamplePoke'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'WaitForSamplePoke', 'Timer', 0,...
        'StateChangeConditions', [WhichSampleIn, 'SampleOnHold'],...
        'OutputActions', SampleLight);
    
    sma = AddState(sma, 'Name', 'SampleOnHold', 'Timer', S.GUI.SampleHoldTime,...
        'StateChangeConditions', ['Tup', 'SampleOn', WhichSampleOut, 'WaitForSamplePoke'],...
        'OutputActions', SampleLight);
    
    sma = AddState(sma, 'Name', 'SampleOn', 'Timer', SampleValveTime,...
        'StateChangeConditions', {'Tup', 'WaitForDelayPoke'},...
        'OutputActions', [SampleLight, SampleValve]);
    
    sma = AddState(sma, 'Name', 'WaitForDelayPoke', 'Timer', 0,...
        'StateChangeConditions', {'Port7In', 'DelayOnHold'},...
        'OutputActions', {'PWM7', 50});
    
    sma = AddState(sma, 'Name', 'DelayOnHold', 'Timer', S.GUI.DelayHoldTime,...
        'StateChangeConditions', {'Tup', 'DelayOn', 'Port7Out', 'WaitForDelayPoke'},...
        'OutputActions', {'PWM7', 50, 'Valve7', 1});
    
    sma = AddState(sma, 'Name', 'DelayOn', 'Timer', GetValveTimes(S.GUI.DelayReward, 7),...
        'StateChangeConditions', {'Tup', 'WaitForChoicePoke'},...
        'OutputActions', {'PWM7', 50, 'Valve7', 1});
    
    sma = AddState(sma, 'Name', 'WaitForChoicePoke', 'Timer', 0,...
        'StateChangeConditions', [WhichChoiceIn, 'ChoiceOnHold'],...
        'OutputActions', ChoiceLight);
    
    sma = AddState(sma, 'Name', 'ChoiceOnHold', 'Timer', ChoiceValveTime,...
        'StateChangeConditions', ['Tup', 'ChoiceOn', WhichChoiceOut, 'WaitForChoicePoke'],...
        'OutputActions', ChoiceLight);
    
    sma = AddState(sma, 'Name', 'ChoiceOn', 'Timer', ChoiceValveTime,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', [ChoiceLight, ChoiceValve]);
    
    
    SendStateMatrix(sma);
    
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial);
        UpdateTrialTypeOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

function UpdateTrialTypeOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    Outcomes(x) = 1;
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.TrialTypeOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
        
    
    
 