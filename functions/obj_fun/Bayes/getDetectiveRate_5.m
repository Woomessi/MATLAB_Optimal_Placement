function detective_rate = getDetectiveRate_5(idx_link1, idx_link2, idx_link3, idx_link4, idx_link5, idx_geodesic0, idx_geodesic1, idx_geodesic2, idx_geodesic3, idx_geodesic4, idx_geodesic5, idx_geodesic6,  size_spot, size_point_target, size_sim, r_obj_offset, theta_obj_offset, target_homo, q_all, my_robot, size_joint, all_tform_spot_link0, all_tform_spot_link1, all_tform_spot_link2, all_tform_spot_link3, all_tform_spot_link4, all_tform_spot_link5, all_tform_spot_link6, fov_vertical, fov_horizontal, h_cone)
idx_geodesic = [idx_geodesic0, idx_geodesic1, idx_geodesic2, idx_geodesic3, idx_geodesic4, idx_geodesic5, idx_geodesic6];
idx_link = [idx_link1, idx_link2, idx_link3, idx_link4, idx_link5];
idx_geodesic = idx_geodesic(idx_link+1);

size_sensor = size(idx_link,2);
group_all_tform_spot = cell(1,size_sensor);
for i = 1:size_sensor
    switch idx_link(i)
        case 0
            group_all_tform_spot{1,i} = all_tform_spot_link0;
        case 1
            group_all_tform_spot{1,i} = all_tform_spot_link1;
        case 2
            group_all_tform_spot{1,i} = all_tform_spot_link2;
        case 3
            group_all_tform_spot{1,i} = all_tform_spot_link3;
        case 4
            group_all_tform_spot{1,i} = all_tform_spot_link4;
        case 5
            group_all_tform_spot{1,i} = all_tform_spot_link5;
        case 6
            group_all_tform_spot{1,i} = all_tform_spot_link6;
    end
end

a = [0;0;0;0.0825;-0.0825;0;0.088;0];
d = [0.333;0;0.316;0;0.384;0;0;0.107];
alpha = [0;-pi/2;pi/2;pi/2;-pi/2;pi/2;pi/2;0];

detection_times = 0;
parfor idx_config = 1:size_sim

    translation = [r_obj_offset(idx_config)*cosd(theta_obj_offset(idx_config));r_obj_offset(idx_config)*sind(theta_obj_offset(idx_config));0]; % 检测目标平移向量
    tform_target = [eye(3),translation;0 0 0 1];
    target_homo_updated = tform_target*target_homo;
    target_updated = target_homo_updated(1:3,:); 

    if mod(idx_config,size(q_all,1)) == 0
        idx_q = size(q_all,1);
    else
        idx_q = mod(idx_config,size(q_all,1));
    end

    q = q_all(idx_q,1:7); 
    config = homeConfiguration(my_robot); 
    for idx_joint = 1:size_joint
        config(idx_joint).JointPosition = q(1,idx_joint);
    end

    for idx_round = 1:size_sensor 

        idx_link_current = idx_link(idx_round);

        transform = eye(4);
        if idx_link_current == 0
            transform = eye(4);
        else
            for i = 1:idx_link_current
                transform = transform*getTformMDH(a(i),d(i),alpha(i),q(i));
            end
        end

        all_tform_spot = group_all_tform_spot{1,idx_round};
        tform_spot = all_tform_spot{1,idx_geodesic(idx_round)};

        for idx_spot = 1:size_spot
            tform_spot{1,idx_spot} = transform*tform_spot{1,idx_spot};
        end

        for idx_point_target = 1:size_point_target
            flag_successful_detection = 0; 
            point_target = target_updated(:,idx_point_target);
            for idx_spot = 1:size_spot
                tform_spot_current = tform_spot{1,idx_spot};
                if tform_spot_current(:,1) == zeros(4,1)
                    break;
                end
                vt = point_target - tform_spot_current(1:3,4);
                l_vt = norm(vt);
                centerline = tform_spot_current(1:3,1);
                cos_theta = dot(vt,centerline)/(l_vt*norm(centerline)); 
                if cos_theta > cosd(min(fov_vertical,fov_horizontal)/2)
                    if l_vt*cos_theta < h_cone 
                        flag_successful_detection = 1;
                        detection_times = detection_times + 1;
                        break
                    end
                end
            end
            if flag_successful_detection == 1 
                break
            end
        end
        if flag_successful_detection == 1 
            break
        end
    end
end
detective_rate = -detection_times/size_sim;
end