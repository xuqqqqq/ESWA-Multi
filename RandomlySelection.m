function flag = RandomlySelection(k)
global route                                                               % ���и����·�� carNum * n * popsize   nΪ���ֵ�����
global road                                                                % ���и����ѡ�����ʻ·�� popsize * n��ͨ����·z��i�㣩
global lengthR                                                             % ���и����ÿ����·�ĳ��� popsize * n
global arrivalTime                                                         % ���и����ÿ�����ֵ�ĵ���ʱ�� popsize * n
global fitness                                                             % ���и������Ӧ��ֵ 1 * popsize
global damage                                                              % ÿ�����ֵ����ʧ popsize * n
global roadNum                                                             % ��ѡ��ĵ�·����
global nodeNum                                                             % ���ֵ�����


flag = 0;
% fitK = fitness(k);
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

p = randperm(nodeNum,1);                                                   % ѡ��һ��Ҫ�任��·�ĵ�
rd = randperm(roadNum,1);                                                  % ����任����һ����·
while roadK(p) == rd
    rd = randperm(roadNum,1);
end

[row,~] = find(routeK == p,1,'first');                                               % �ҵ�p���·��λ�ã��ڵڼ���·���ڼ���λ�ã�
if isempty(row)
    return;
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

