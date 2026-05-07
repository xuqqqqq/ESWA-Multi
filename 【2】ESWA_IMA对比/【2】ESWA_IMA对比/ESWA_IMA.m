clear;
clc;

global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
global popsize                                                             % 种群规模
global carNum                                                              % 最大车辆使用数量
global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
global v                                                                   % 车辆行驶初始速度
global demand                                                              % 各个点的需求量
global s                                                                   % 各个点的服务时间
global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
global maxLoad                                                             % 车辆的最大装载量
global omega                                                               % 每个点的单位损失成本 1 * n
global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
global recoveryRateNode                                                    % 每个点的恢复率 n * 1
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
global deteriorationRateDMax                                               % 最大损坏率
global recoveryRateDmin                                                    % 最小恢复率

% ================= 新增的多周期全局变量 =================
global numPeriods       % 总周期数
global Qp               % 每个周期的物资补货上限
global Tshift           % 每个周期的时长（时间窗）
global penaltyWeight    % 违反物资上限的惩罚权重
global totalCarNum      % 展开后的总车辆数 (numPeriods * carNum)
% =======================================================

nodeNum = 100;
depot = 101;                                                               % 仓库编号
data = load('r101-25-para.txt');
% x = data(:,2);                                                             % 受灾点的横纵坐标
% y = data(:,3);
demand = data(:,4);                                                        % 受灾点的物资需求量
s = data(:,5);                                                             % 受灾点的服务时间
D(:,:,1) = load('r101-25-Dshort.txt');
D(:,:,2) = load('r101-25-D.txt');
D(:,:,3) = load('r101-25-Dlong.txt');
nodeData = load('nodeRate.txt');
initialDeteriorationNode = nodeData(:,1);
deteriorationRateNode = nodeData(:,2);
recoveryRateNode = nodeData(:,3);
initialDeteriorationD(:,:,1) = load('initialDshort.txt');
initialDeteriorationD(:,:,2) = load('initialD.txt');
initialDeteriorationD(:,:,3) = load('initialDlong.txt');
deteriorationRateD(:,:,1) = load('deteriorationRateDshort.txt');
deteriorationRateD(:,:,2) = load('deteriorationRateD.txt');
deteriorationRateD(:,:,3) = load('deteriorationRateDlong.txt');
recoveryRateD = load('recoveryRateD.txt');



zzk = 1;
zzkMax = 1;
while zzk <= zzkMax
    
deteriorationRateDMax = 1;
recoveryRateDmin = 0.01;

omega = ones(1,nodeNum);
maxLoad = 200;
v = 1;                                                                     % 1km/min

% ================= 设置多周期参数 =================
numPeriods = 3;                       % 假设分 3 个周期进行救援
Qp = 500;                             % 每个周期的可用物资总上限(需根据需求量微调)(1458/3)486
Tshift = 480;                         % 每个周期的时长 480 分钟（1440/3）
penaltyWeight = 10000;                % 惩罚系数
% =================================================

popsize = 20;
t = 1;
iterMax = 3000;
carNum = floor(25*nodeNum/200);
roadNum = 3;

totalCarNum = numPeriods * carNum;    % 总行数 = 周期数 * 每周期车数

route = zeros(totalCarNum,nodeNum,popsize);                                % 初始化route矩阵
numR = zeros(1,popsize);                                                   % 初始化numR向量
lengthR = zeros(popsize,totalCarNum);                                      % 初始化lengthR
arrivalTime = zeros(popsize,nodeNum);                                      % 初始化arrivalTime
damage = zeros(popsize,nodeNum);                                           % 初始化每个受灾点的损失
fitness = zeros(1,popsize);
initialPopulation();
initialObjective();
% swapScore = [1 1 1];
% insertScore = [1 1 1];
% exchangeScore = [1 1 1];
% relocationScore = [1 1 1];

[globalBest,index] = min(fitness);
globalBestRoute = route(:,:,index);
globalBestDamage = damage(index,:);
globalBestTime = arrivalTime(index,:);
globalBestRoad = road(index,:);
globalBestLengthR = lengthR(index,:);
globalBestNumR = numR(index);
Pc = 0.7;
% trace = zeros(1,iterMax);
tic
while t <= iterMax
    for k = 1:popsize/2
        %% 交叉
        if rand < Pc
            p = randperm(popsize,3);
            while ismember(k,p)
                p = randperm(popsize,3);
            end
            f = fitness(p);
            [~,indexf] = min(f);
            parent = p(indexf);
            crossover(k,parent);
            
            
            %%变邻域下降
            alpha = 1;
            while alpha <= 4
                switch alpha
                    case 1
                        flag = Swap(k);
                    case 2
                        flag = Insert(k);
                    case 3
                        flag = Exchange(k);
                    case 4
                        flag = Relocate(k);
                end
                if flag == 1                                                   % flag=1时表明解有更新
                    alpha = 1;
                else
                    alpha = alpha + 1;
                end
            end
        end
        
        %% 道路变化
        beta = 1;
        while beta
            if rand < 0.5
                flag = RandomlySelection(k);
            else
                flag = GreedySelection(k);
            end
            if ~flag
                beta = 0;
            end
        end
    end
    

        

        
    
    [currentBest,index] = min(fitness);
    if (round(currentBest*10^4)/10^4) < (round(globalBest*10^4)/10^4)
        globalBest = currentBest;
        globalBestRoute = route(:,:,index);
        globalBestDamage = damage(index,:);
        globalBestTime = arrivalTime(index,:);
        globalBestRoad = road(index,:);
        globalBestLengthR = lengthR(index,:);
        globalBestNumR = numR(index);
        iterTime = toc;
        disp(['第 ',num2str(t),' 代最优解为：',num2str(globalBest),'。所用时间为：',num2str(iterTime),'s']);
    end
    trace(t,zzk) = globalBest;
    t = t+1;
end
obj(zzk,1) = globalBest;
% r = 1:globalBestNumR;
% totalroadDamage = roadDamage(globalBestRoute,globalBestLengthR,globalBestRoad,globalBestTime,r);
% roadDamageMatrix(zzk,1) = totalroadDamage;
% disp(['第 ',num2str(zzk),' 次的总道路损失为：',num2str(totalroadDamage)]);
zzk = zzk + 1;
toc
end



plot(1:iterMax,trace);