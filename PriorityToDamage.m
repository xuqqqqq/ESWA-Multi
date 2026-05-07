clear;
clc;

global route                                                               % 所有个体的路径 carNum * n   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 n
% global numR                                                                % 所有个体的路径数量 1
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 n
global fitness                                                             % 所有个体的适应度值 1
global damage                                                              % 每个受灾点的损失 n
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
% global distance                                                            % 行驶路径长度 1 * popsize

nodeNum = 25;
depot = 101;                                                               % 仓库编号
data = load('C201-25-para.txt');
x = data(:,2);                                                             % 受灾点的横纵坐标
y = data(:,3);
demand = data(:,4);                                                        % 受灾点的物资需求量
s = data(:,5);                                                             % 受灾点的服务时间
D(:,:,1) = load('C201-25-Dshort.txt');
D(:,:,2) = load('C201-25-D.txt');
D(:,:,3) = load('C201-25-Dlong.txt');
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

dR = deteriorationRateNode ./ recoveryRateNode;
    
deteriorationRateDMax = 1;
recoveryRateDmin = 0.01;

omega = ones(1,nodeNum);
maxLoad = 200;
v = 1;                                                                     % 1km/min

popsize = 20;
t = 1;
iterMax = 1000;
carNum = floor(25*nodeNum/100);
roadNum = 3;

route = zeros(carNum,nodeNum);                                     % 初始化route矩阵
% numR = zeros(1,popsize);                                                   % 初始化numR向量
lengthR = zeros(1,carNum);                                           % 初始化lengthR
arrivalTime = zeros(1,nodeNum);                                      % 初始化arrivalTime
damage = zeros(1,nodeNum);                                           % 初始化每个受灾点的损失
% fitness = zeros(1,popsize);
% distance = zeros(1,popsize);

[rankInitialDamage,index] = sort(dR(1:nodeNum),'descend');

load = zeros(1,carNum);
for j = 1:nodeNum
    flag = 0;
    for i = 1:carNum
        if lengthR(i) == 0 && j <= carNum
            route(i,1) = index(j);
            road(index(j)) = 1;
            lengthR(i) = lengthR(i) + 1;
            vkz = speedv(initialDeteriorationD(depot,index(j),road(index(j))));
            t = D(depot,index(j),road(index(j))) / vkz;
            for z = 2:3
                vkzNew = speedv(initialDeteriorationD(depot,index(j),z));
                tNew = D(depot,index(j),z) / vkzNew;
                if t > tNew
                    road(index(j)) = z;
                    vkz = vkzNew;
                    t = tNew;
                end
            end
            arrivalTime(index(j)) = D(depot,index(j),road(index(j))) / vkz;
            break;
        end
        
        if lengthR(i) ~= 0 && i == 1 && j > carNum
            rP = i;               % 先选择index(j)点放到rP条路
            roadP = 1;
            Rzt = Rt(roadP,(arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)))),route(i,lengthR(i)),index(j));
            vkz = speedv(Rzt);
            t = D(route(i,lengthR(i)),index(j),roadP) / vkz + arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)));
            for z = 2:3
                Rzt = Rt(z,(arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)))),route(i,lengthR(i)),index(j));
                vkzNew = speedv(Rzt);
                tNew = D(route(i,lengthR(i)),index(j),z) / vkzNew + arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)));
                if t > tNew
                    roadP = z;
                    vkz = vkzNew;
                    t = tNew;
                end
            end
            tempArrivalTime = t;
            flag = 1;
        end
        
        if i ~= 1 && j > carNum
            roadiP = 1;
            Rzt = Rt(roadiP,(arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)))),route(i,lengthR(i)),index(j));
            vkz = speedv(Rzt);
            t = D(route(i,lengthR(i)),index(j),roadiP) / vkz + arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)));
            for z = 2:3
                Rzt = Rt(z,(arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)))),route(i,lengthR(i)),index(j));
                vkzNew = speedv(Rzt);
                tNew = D(route(i,lengthR(i)),index(j),z) / vkzNew + arrivalTime(route(i,lengthR(i))) + s(route(i,lengthR(i)));
                if t > tNew
                    roadiP = z;
                    vkz = vkzNew;
                    t = tNew;
                end
            end
            
            if t < tempArrivalTime
                rP = i;
                tempArrivalTime = t;
                roadP = roadiP;
            end
            flag = 1;
        end
    end
    if flag
        lengthR(rP) = lengthR(rP) + 1;
        route(rP,lengthR(rP)) = index(j);
        road(index(j)) = roadP;
        arrivalTime(index(j)) = tempArrivalTime;
    end
end
for i = 1:nodeNum
    damage(i) = Dt(i,arrivalTime(i));
end
fitness = sum(damage)
            
                
            

