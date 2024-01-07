%filename = "2023-12-29-ads-b-iq-6_2023-12-30T04_37_36_338.wav";
filename = "2023-12-29-ads-b-iq-8M-1_2023-12-30T05_04_24_336.wav";

%[y, f_s] = audioread(filename, [1, 50e6], "double");
[y, f_s] = audioread(filename, "double");

%y = y(945000:950000, :);

magnitude = approx_magnitude(y);

preamble_high   = [0, 1, 3.5, 4.5] .* 8 + 1;
preamble_len    = 64;
preamble_b      = 0 * ones(preamble_len, 1);
for ii = preamble_high
    preamble_b(ii:(ii+4-1)) = 1;
end
preamble_b = preamble_b / sum(preamble_b);

mean_b = ones(preamble_len, 1) / preamble_len;

preamble_s  = conv(preamble_b(end:-1:1), magnitude);
preamble_sn = conv(mean_b, magnitude);
mag_delayed = [zeros(preamble_len-1,1); magnitude];

mag_filter_b = [1,1,1,1] / 4;
mag_filtered = conv(mag_filter_b, mag_delayed);

preamble_sn_delayed = [zeros(preamble_len-1, 1); preamble_sn];
bit_threshold = preamble_sn_delayed;

SSN_ratio  = 2.0;

preamble_det_v = (preamble_s >= (SSN_ratio * preamble_sn));
preamble_det_i = find(preamble_det_v);

preamble_det_g = preamble_det_v .* preamble_s;

preamble_det_fi = [];

det_window_len = 4;
for i_det = preamble_det_i.'
    if i_det + det_window_len > length(preamble_det_g)
        continue
    end

    [max_value, max_index] = max(preamble_det_g(i_det:(i_det+det_window_len))); %need highest S/SN, so assuming constant SN to avoid division
    if max_value > 0
        preamble_det_g(i_det:(i_det+120*8)) = 0;
        det_start = i_det + max_index - 1;

        preamble_det_fi = [preamble_det_fi; det_start];
        bit_threshold(det_start:(det_start + 2*preamble_len)) = max_value/2; %(max_value - preamble_sn(det_start)) / 2 + preamble_sn(det_start);

        % max_value/4 + preamble_sn(det_start)/2 -- 15/22
        % max_value/2 - 13/19
    end
end


message_data = [];
crc_matched_msgs = [];

for ii = preamble_det_fi.'
    if ii > (length(mag_filtered) - 120*8)
        continue
    end
    
    msg.start_index = ii;
    msg.preamble_mag = preamble_s(ii);
    msg.data_raw = zeros(120, 1);
    msg.data_bits = zeros(120, 1);
    msg.bit_threshold = zeros(120, 1);
    msg.preamble_plus_noise_mag = preamble_sn(ii);
    msg.ssnr = msg.preamble_mag / msg.preamble_plus_noise_mag;
    msg.ssnr_db = 20*log10(msg.ssnr); %power
    msg.data_slice = [];

    for jj = 1:120
        bit_index = ii + 8*(jj-1) + 4 - 1;
        msg.data_raw(jj)        = mag_filtered(bit_index);
        msg.data_bits(jj)       = mag_filtered(bit_index) > bit_threshold(bit_index);
        msg.bit_threshold(jj)   = bit_threshold(bit_index);
    end

    msg = check_ads_b_crc(msg);


    [msg_preamble, msg_df, ~] = process_message(msg);
    msg.preamble = int(msg_preamble);
    msg.df = int(msg_df);

    if msg.final_crc_valid && (msg.ssnr_db > 7)
        figure(3); plot(msg.data_raw(9:end), 'o'); hold on; plot(msg.bit_threshold(9:end)); hold off;
        msg.data_slice = y(ii - 500 : ii + 1500, :);
        crc_matched_msgs = [crc_matched_msgs; msg];
    end

    message_data = [message_data; msg];
end

fh_output_iq = fopen("adsb_test_data_2023_12_29_iq.txt", "w");
fh_output_msg = fopen("adsb_test_data_2023_12_29_msg.txt", "w");
for msg = crc_matched_msgs.'
    for ii = 1:length(msg.data_slice)
        fprintf(fh_output_iq, "%0.8f %0.8f\n", msg.data_slice(ii, 1), msg.data_slice(ii, 2));
    end
    fprintf(fh_output_msg, "%s\n", dec2hex(bin_to_dec(msg.data_bits(9:end))));
end

fclose(fh_output_iq);
fclose(fh_output_msg);
return

function msg_out = check_ads_b_crc(msg)

    data_bits = msg.data_bits(9:end);
    crc_match = compute_crc(data_bits);

    msg_out = msg;
    msg_out.correction_index = 0;
    msg_out.initial_crc_valid = crc_match;
    msg_out.final_crc_valid = 0;
    
    if (crc_match)
        msg_out.final_crc_valid = 1;
        return
    end    
    
    threshold_distance = abs(msg.data_raw(9:end) - msg.bit_threshold(9:end));
    figure(2); plot(msg.data_raw(9:end), 'o'); hold on; plot(msg.bit_threshold(9:end)); hold off;

    [sorted_d, sorted_i] = sort(threshold_distance);
    for ii=1:5 %one attempt?
        data_bits(sorted_i) = ~data_bits(sorted_i);
        crc_match = compute_crc(data_bits);
        if crc_match
            msg_out.final_crc_valid = 1;
            return
        end
    end
    
end

function crc_match = compute_crc(data_bits)
    generator = str2vec("1111111111111010000001001");
    
    for ii = 1:(112-24)
        if data_bits(ii)
            data_bits(ii:(ii+24)) = xor(data_bits(ii:(ii+24)), generator);
        end
    end

    remainder = data_bits(end-23:end);    
    crc_match = all(remainder == 0);
end

function r = str2vec(s)
    r = [];
    ss = s.char();
    for ii = 1:length(ss)
        if ss(ii) == " "
            continue;
        end
        r = [r; str2double(ss(ii))];
    end
end

function [msg_preamble, msg_df, msg_bin] = process_message(msg)
    print_enable = 0;
    ignore_non_ads_b = 1;
        
    msg_preamble = bin_to_dec(msg.data_bits(1:8));
    data_bits = msg.data_bits(9:end);

    msg_bin = 0;
    DF_keys = [0, 4, 5, 11, 16, 17, 18, 19, 20, 21, 24];
    DF_values = ["short A-A surv", "alt reply", "ident reply", "all-call reply", "long A-A surv", "ext squitter", "ext squitter, non trans", "mil ext squitter", "comm-b alt", "comm-b ident", "comm-b ext"];
    DF_dict = dictionary(DF_keys, DF_values);
    
    CA_keys = [0, 4, 5, 6];
    CA_values = ["level 1", "level 2+ gnd", "level 2+ air", "level 2+ g/a"];
    CA_dict = dictionary(CA_keys, CA_values);

    msg_df = bin_to_dec(data_bits(1:5));
    if ~isKey(DF_dict, msg_df)
        if print_enable
            fprintf("Invalid df: %d\n", msg_df);
        end
        return
    end
    %DF_dict(msg_df)
    if ~ignore_non_ads_b && (msg_df ~= 17) && (msg_df ~= 18) && (msg_df ~= 19)
        if print_enable
            fprintf("Ignoring non-ADS-B message: %s\n", DF_dict(msg_df));
        end
        return 
    end

    msg_ca = bin_to_dec(data_bits(6:8));
    if ~ignore_non_ads_b && ~isKey(CA_dict, msg_ca)
        if print_enable
            fprintf("Invalid CA: %d\n", msg_ca);
        end
        return
    end

    msg_icao = bin_to_dec(data_bits(9:32));
    msg_tc   = bin_to_dec(data_bits(33:37));
    
    if (msg_df == 17) || (msg_df == 18) || (msg_df == 19)
        msg_bin = bin_to_dec(data_bits);
        if (isKey(CA_dict, msg_ca))
            fprintf("ADS-B: CA=%s  ICAO=%d  TC=%d   -- SSNR=%0.1f dB\n", CA_dict(msg_ca), msg_icao, msg_tc, msg.ssnr_db);
        end
    end

    %CA_dict(msg_ca)
end

function r = bin_to_dec(bin_vec)
    r = fi(0, 0, length(bin_vec));
    for ii = 1:length(bin_vec)
        b = bin_vec(ii);
        r = fi(2*r + b, 0, length(bin_vec));
    end
end

function m = approx_magnitude(iq)
    L = abs(max(iq, [], 2));
    S = abs(min(iq, [], 2));
    %m = L + 0.4*S;
    m = L + 0.375*S;
end
