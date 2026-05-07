function crossover(k,p)
global route
global road
global lengthR
global numR
global arrivalTime
global fitness
global damage
global demand
global maxLoad

childRoute = route(:,:,k);
childlengthR = lengthR(k,:);
childnumR = numR(k);

similarMatrix = zeros(numR(k),numR(p));
for i = 1:numR(k)
    for j = 1:numR(p)
        flag = ismember(route(i,1:lengthR(k,i),k),route(j,1:lengthR(p,j),p));
        similarMatrix(i,j) = sum(flag);
    end
end

[row,col] = find(similarMatrix == max(max(similarMatrix)));
Rk = row(1);
Rp = col(1);

flag = ismember(route(Rk,1:lengthR(k,Rk),k),route(Rp,1:lengthR(p,Rp),p));
insertRoute = [];
originalRoute = [];
for i = 1:length(flag)
    if flag(i) == 0
        insertRoute = [insertRoute route(Rk,i,k)];
    else
        originalRoute = [originalRoute route(Rk,i,k)];
    end
end

childRoute(Rk,:) = 0;
childRoute(Rk,1:length(originalRoute)) = originalRoute;
childlengthR(Rk) = length(originalRoute);

if ~isempty(insertRoute)
    for i = 1:length(insertRoute)
        r = randperm(childnumR,1);
        load = sum(demand(childRoute(r,1:childlengthR(r))));
        while (load + demand(insertRoute(i))) > maxLoad
            r = randperm(childnumR,1);
            load = sum(demand(childRoute(r,1:childlengthR(r))));
        end

        if childlengthR(r) == 0
            point = 1;
        else
            point = randperm(childlengthR(r),1);
        end

        childlengthR(r) = childlengthR(r) + 1;
        temp = [childRoute(r,1:point-1) insertRoute(i) childRoute(r,point:end-1)];
        childRoute(r,:) = temp;
    end
end

childRoad = road(k,:);
childarrivalTime = arrivalTime(k,:);
childDamage = damage(k,:);
rUpdate = 1:childnumR;
[childfitness,childDamage,childRoad,childarrivalTime] = objectiveK(childRoute,childlengthR,childRoad,childarrivalTime,childDamage,rUpdate);

if childfitness < fitness(k)
    fitness(k) = childfitness;
    route(:,:,k) = childRoute;
    road(k,:) = childRoad;
    numR(k) = childnumR;
    lengthR(k,:) = childlengthR;
    arrivalTime(k,:) = childarrivalTime;
    damage(k,:) = childDamage;
end
end
