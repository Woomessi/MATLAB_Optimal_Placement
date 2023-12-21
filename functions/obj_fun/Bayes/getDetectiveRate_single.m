function detective_rate = getDetectiveRate_single(idx_link, idx_geodesic, size_spot, size_point_target, size_sim, r_obj_offset, theta_obj_offset, target_homo, q_all, my_robot, size_joint, all_tform_spot, all_tform_spot_link0, all_tform_spot_link1, all_tform_spot_link2, all_tform_spot_link3, all_tform_spot_link4, all_tform_spot_link5, all_tform_spot_link6, fov_vertical, fov_horizontal, h_cone)

% 提取当前连杆TOF模块的齐次变换矩阵
switch idx_link
    case 0
        all_tform_spot = all_tform_spot_link0;
    case 1
        all_tform_spot = all_tform_spot_link1;
    case 2
        all_tform_spot = all_tform_spot_link2;
    case 3
        all_tform_spot = all_tform_spot_link3;
    case 4
        all_tform_spot = all_tform_spot_link4;
    case 5
        all_tform_spot = all_tform_spot_link5;
    case 6
        all_tform_spot = all_tform_spot_link6;
end

% DH参数
a = [0;0;0;0.0825;-0.0825;0;0.088;0];
d = [0.333;0;0.316;0;0.384;0;0;0.107];
alpha = [0;-pi/2;pi/2;pi/2;-pi/2;pi/2;pi/2;0];

%%%%%%%%%%%%%%%%%%%
%%% 蒙特卡洛仿真 %%%
%%%%%%%%%%%%%%%%%%%

detection_times = 0; % 检测到目标的次数
parfor idx_config = 1:size_sim

    % 检测目标坐标信息
    translation = [r_obj_offset(idx_config)*cosd(theta_obj_offset(idx_config));r_obj_offset(idx_config)*sind(theta_obj_offset(idx_config));0]; % 检测目标平移向量
    tform_target = [eye(3),translation;0 0 0 1]; % 平移变换矩阵
    target_homo_updated = tform_target*target_homo;
    target_updated = target_homo_updated(1:3,:); % 平移变换后的检测目标

    if mod(idx_config,size(q_all,1)) == 0
        idx_q = size(q_all,1);
    else
        idx_q = mod(idx_config,size(q_all,1));
    end

    % 当前关节角配置
    q = q_all(idx_q,1:7); % 当前关节空间角
    config = homeConfiguration(my_robot); % 关节空间配置结构体生成
    for idx_joint = 1:size_joint % 遍历每个关节
        config(idx_joint).JointPosition = q(1,idx_joint);
    end

    % 对各连杆上的传感器进行配置
    % 当前位形空间下当前连杆相对于基坐标系的齐次变换矩阵
    % link_name = ["panda_link0" "panda_link1" "panda_link2" "panda_link3" "panda_link4" "panda_link5" "panda_link6" "panda_link7"];
    % transform = getTransform(my_robot,config,link_name(idx_link));

    transform = eye(4);
    if idx_link == 0
        transform = eye(4);
    else
        for i = 1:idx_link
            transform = transform*getTformMDH(a(i),d(i),alpha(i),q(i));
        end
    end

    % 选择当前连杆的传感器布局方案
    tform_spot = all_tform_spot{1,idx_geodesic};

    % 通过齐次变换获得当前位形空间下的传感器ToF模块位姿
    for idx_spot = 1:size_spot
        tform_spot{1,idx_spot} = transform*tform_spot{1,idx_spot};
    end

    % 作图
    % plotRobot(my_robot,config,size_spot,tform_spot,h_cone, fov_horizontal,target_updated);

    % ToF检测
    for idx_point_target = 1:size_point_target
        flag_successful_detection = 0; %循环跳出标识
        point_target = target_updated(:,idx_point_target); %目标点设置
        for idx_spot = 1:size_spot
            tform_spot_current = tform_spot{1,idx_spot};
            if tform_spot_current(:,1) == zeros(4,1)
                break;
            end
            vt = point_target - tform_spot_current(1:3,4); %圆锥顶点到目标点的向量
            l_vt = norm(vt);
            centerline = tform_spot_current(1:3,1); %圆锥中心线
            cos_theta = dot(vt,centerline)/(l_vt*norm(centerline)); %夹角余弦
            if cos_theta > cosd(min(fov_vertical,fov_horizontal)/2) %夹角是否小于视场角的一半？
                if l_vt*cos_theta < h_cone %测距值在中心线方向的投影距离是否在量程内
                    % range_all(idx_spot, idx_point_target) = norm(vt);
                    % range_old(idx_spot, 1) = range_now(idx_spot, 1);
                    % if l_vt < range_old(idx_spot, 1)
                    %     range_now(idx_spot, 1) = l_vt;
                    % end
                    flag_successful_detection = 1;
                    detection_times = detection_times + 1;
                    break
                end
            end
        end
        if flag_successful_detection == 1 %跳出两重循环
            break
        end
    end
    % 作图
    % plotRobot(my_robot,config,size_spot,tform_spot,h_cone, fov_horizontal,target1);
end
detective_rate = -detection_times/size_sim;
end