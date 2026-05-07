clear;
clc;
data = load('rc203-25.txt');
cityNum = size(data,1);
x = data(:,2);
y = data(:,3);
demand = data(:,4);
s = data(:,7);
D = zeros(cityNum);                                                          % 任意两个城市距离矩阵
for i = 1:cityNum                                                            % 计算城市之间距离
    for j = 1:cityNum
        D(i,j) = ((x(i) - x(j))^2 + (y(i) - y(j))^2)^0.5;
    end
end
Dshort = zeros(cityNum);
Dlong = zeros(cityNum); 
for i = 1:size(D,1)
    for j = 1:size(D,2)
        if i ~= j
            Dshort(i,j) = D(i,j) - D(i,j) * (0.9-0.4) + 0.5;
            Dlong(i,j) = D(i,j) + D(i,j) * (0.9-0.4) + 0.5;
        end
    end
end
num = 1:cityNum;
para = [num' x y demand s];
save('rc203-25-para.txt','para','-ascii');
save('rc203-25-D.txt', 'D', '-ascii');
save('rc203-25-Dshort.txt', 'Dshort', '-ascii');
save('rc203-25-Dlong.txt', 'Dlong', '-ascii');