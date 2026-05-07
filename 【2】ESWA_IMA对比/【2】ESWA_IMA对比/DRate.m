data = ones(101,101);
initialDshort = rand(101,101);
initialD = rand(101,101);
initialDlong = rand(101,101);
deteriorationRateDshort = ones(101,101) .* (rand(101,101) .* (1 - 0.8) + 0.8);
deteriorationRateD = ones(101,101) .* (rand(101,101) .* (0.8 - 0.6) + 0.6);
deteriorationRateDlong = ones(101,101) .* (rand(101,101) .* (0.6 - 0.4) + 0.4);
recoveryRateD = ones(101,101) .* (rand(101,101) .* (0.4 - 0.01) + 0.01);
for i = 1:101
    for j = 1:101
        if i == j
            initialD(i,j) = 0;
            deteriorationRateDshort(i,j) = 0;
            deteriorationRateD(i,j) = 0;
            deteriorationRateDlong(i,j) = 0;
            recoveryRateD(i,j) = 0;
            initialDshort(i,j) = 0;
            initialDlong(i,j) = 0;
        end
    end
end
save('initialDshort.txt','initialDshort','-ascii');
save('initialD.txt','initialD','-ascii');
save('initialDlong.txt','initialDlong','-ascii');
save('deteriorationRateDshort.txt','deteriorationRateDshort','-ascii');
save('deteriorationRateD.txt','deteriorationRateD','-ascii');
save('deteriorationRateDlong.txt','deteriorationRateDlong','-ascii');
save('recoveryRateD.txt','recoveryRateD','-ascii');