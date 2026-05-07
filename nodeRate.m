data = ones(100,1);
initialRate = data .* rand(100,1);
deteriorationRate = data .* (rand(100,1) .* (1 - 0.4) + 0.4);
recoveryRate = data .* (rand(100,1) .* (0.4 - 0.01) + 0.01);
x = [initialRate deteriorationRate recoveryRate];                          % ³õÊ¼ËğÊ§¡¢»Ù»µÂÊ£¬»Ö¸´ÂÊ
save('nodeRate.txt','x','-ascii');