% i 为受灾点编号
% ai 为车辆到达受灾点的时间
function Dit = Dt(i,ai)
global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
global recoveryRateNode                                                    % 每个点的恢复率 n * 1
global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
Dit = initialDeteriorationNode(i) .* exp(-recoveryRateNode(i) .* ai) + deteriorationRateNode(i) ./ recoveryRateNode(i) .* (1 - exp(-recoveryRateNode(i) .* ai));
end