function vkz = speedv(Rzt)
global v                                                                   % 车辆行驶初始速度
global deteriorationRateDMax                                               % 最大损坏率
global recoveryRateDmin                                                    % 最小恢复率
vkz = (1 - Rzt .* recoveryRateDmin ./(0.814 .* deteriorationRateDMax)) .* v;
end