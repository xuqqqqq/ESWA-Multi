function flag = GreedySelection(k)
global route                                                               % ���и����·�� carNum * n * popsize   nΪ���ֵ�����
global road                                                                % ���и����ѡ�����ʻ·�� popsize * n��ͨ����·z��i�㣩
global lengthR                                                             % ���и����ÿ����·�ĳ��� popsize * n
global arrivalTime                                                         % ���и����ÿ�����ֵ�ĵ���ʱ�� popsize * n
global fitness                                                             % ���и������Ӧ��ֵ 1 * popsize
global damage                                                              % ÿ�����ֵ����ʧ popsize * n
global roadNum                                                             % ��ѡ��ĵ�·����
global depot                                                               % �ֿ���
global nodeNum                                                             % ���ֵ�����
global initialDeteriorationD                                               % ÿ��·�ĳ�ʼ�ٻ��̶� (n+1) * (n+1) * 3
global s                                                                   % ������ķ���ʱ��

flag = 0;
% fitK = fitness(k);
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

p = randperm(nodeNum,1);                                                   % ѡ��һ��Ҫ�任��·�ĵ�
rd = 1;                                                                    % ѡ��ͨ���ٶ�����·
[row,col] = find(routeK == p,1,'first');                                             % �ҵ�p�����ڵ��к���
if isempty(row) || lengthRK(row) <= 0 || col > lengthRK(row)
    return;
end
tempRoute = [depot routeK(row,1:lengthRK(row))];
if col == 1
    vkz = speedv(initialDeteriorationD(tempRoute(col),tempRoute(col + 1),rd));
else
    Rzt = Rt(rd,(arrivalTimeK(tempRoute(col)) + s(tempRoute(col))),tempRoute(col),tempRoute(col+1));
    vkz = speedv(Rzt);
end

for i = 2:roadNum
    if col == 1
        vkzNew = speedv(initialDeteriorationD(tempRoute(col),tempRoute(col + 1),i));
    else
        Rzt = Rt(i,(arrivalTimeK(tempRoute(col)) + s(tempRoute(col))),tempRoute(col),tempRoute(col+1));
        vkzNew = speedv(Rzt);
    end
    
    if vkzNew > vkz
        rd = i;
        vkz = vkzNew;
    end
end

roadK(p) = rd;
[fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,row);
if fitK < fitness(k)
    fitness(k) = fitK;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    flag = 1;
end
end
