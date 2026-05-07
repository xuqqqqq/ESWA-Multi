clc;
clear;

data = load('C101-25-para.txt');
x = data(:,2);                                                             % 受灾点的横纵坐标
y = data(:,3);
nodeNum = length(x)-1;
idx = load('omega1.txt');
for i = 1:nodeNum
    if i == 1
        h1 = scatter(x(i),y(i),'g','filled');
    else
        scatter(x(i),y(i),'g','filled');
    end
    
    %     text(x(i),y(i),num2str(i));
    text(x(i),y(i),['  ' num2str(idx(i))]);
    hold on
end
h2 = scatter(x(end),y(end),120,'rp','filled');
legend([h1 h2],'Disaster nodes','depot','FontName', 'Times New Roman','FontSize',12);
xlabel('x','FontName', 'Times New Roman','FontSize',12);
ylabel('y','FontName', 'Times New Roman','FontSize',12);
X = [x(1:end-1),y(1:end-1)];
idx = zeros(nodeNum,1);
% idx(1:11) = 1;
% idx(75) = 1;
% idx(12:19) = 2;
% idx(92:100) = 3;
% idx(31:39) = 4;
% idx(20:30) = 5;
% idx(40:52) = 6;
% idx(53:60) = 7;
% idx(61:69) = 8;
% idx(72) = 8;
% idx(74) = 8;
% idx(70:71) = 9;
% idx(73) = 9;
% idx(76:81) = 9;
% idx(82:91) = 10;
% idx(1:11) = 1;
% idx(75) = 1;
% idx(12:19) = 6;
% idx(92:100) = 11;
% idx(31:39) = 16;
% idx(20:30) = 21;
% idx(40:52) = 26;
% idx(53:60) = 31;
% idx(61:69) = 36;
% idx(72) = 36;
% idx(74) = 36;
% idx(70:71) = 41;
% idx(73) = 41;
% idx(76:81) = 41;
% idx(82:91) = 46;
% save('omega3.txt','idx','-ascii');
% data = ones(100,1);
% for i = 1:nodeNum
%     initialRate(i,1) = (idx(i)-1)*0.1 + rand .* 0.1;
%     deteriorationRate(i,1) = (idx(i)-1)*0.1 + rand .* 0.1;
% end
% x = [initialRate deteriorationRate]; 
% save('clusterNodeRate.txt','x','-ascii');
