import os
import time
import pickle
import cv2
import mediapipe as mp
import numpy as np
import random
import edcc
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.auth.transport.requests import Request

mp_hands = mp.solutions.hands
hands_auth = mp_hands.Hands(static_image_mode=False, max_num_hands=1, min_detection_confidence=0.75)
hands_gesture = mp_hands.Hands(static_image_mode=False, min_detection_confidence=0.3, min_tracking_confidence=0.5)
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

config = edcc.EncoderConfig(29, 5, 5, 10)
encoder = edcc.create_encoder(config)

STORED_PALMPRINT_DATA_DIR = "palmprint_data"
stored_palmprint_path = os.path.join(STORED_PALMPRINT_DATA_DIR, "stored_template.bmp")

model_dict = pickle.load(open('./model.p', 'rb'))
model = model_dict['model']

first_palm_stored = False

SCOPES = ['https://www.googleapis.com/auth/drive.file']
CREDENTIALS_FILE = '/Users/adham/Downloads/client_secret_312194384049-ef9dg6go6f2rbvhqtfagbhfnimmf7qpf.apps.googleusercontent.com.json'

ADHAM_FILE_PATH = '/Users/adham/Desktop/JSON/Screenshot 2024-05-19 at 11.28.57 PM.png'
TEST_FILE_PATH = '/Users/adham/Desktop/JSON/Screenshot 2024-05-19 at 11.28.57 PM.png'

layer = 2

def create_drive_service():
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    service = build('drive', 'v3', credentials=creds)
    return service

drive_service = create_drive_service()

def setup_drive_folders():
    folder_name = 'Drag-And-Drop'
    folder_id = None

    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    results = drive_service.files().list(q=query, fields="files(id, name)").execute()
    items = results.get('files', [])

    if items:
        folder_id = items[0]['id']
        print(f"Folder '{folder_name}' already exists.")
    else:
        file_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder'
        }
        folder = drive_service.files().create(body=file_metadata, fields='id').execute()
        folder_id = folder.get('id')
        print(f"Folder '{folder_name}' created.")

    subfolders = [f'phalange {i}' for i in range(1, 13)]
    subfolder_ids = {}

    for subfolder in subfolders:
        query = f"name='{subfolder}' and mimeType='application/vnd.google-apps.folder' and '{folder_id}' in parents and trashed=false"
        results = drive_service.files().list(q=query, fields="files(id, name)").execute()
        items = results.get('files', [])

        if items:
            subfolder_id = items[0]['id']
            print(f"Subfolder '{subfolder}' already exists.")
        else:
            file_metadata = {
                'name': subfolder,
                'mimeType': 'application/vnd.google-apps.folder',
                'parents': [folder_id]
            }
            subfolder_created = drive_service.files().create(body=file_metadata, fields='id, name').execute()
            subfolder_id = subfolder_created['id']
            print(f"Subfolder '{subfolder}' created.")

        subfolder_ids[subfolder] = {}
        for l in range(1, layer + 1):
            layer_folder = f"layer {l}"
            query = f"name='{layer_folder}' and mimeType='application/vnd.google-apps.folder' and '{subfolder_id}' in parents and trashed=false"
            results = drive_service.files().list(q=query, fields="files(id, name)").execute()
            items = results.get('files', [])

            if items:
                subfolder_ids[subfolder][f'layer {l}'] = items[0]['id']
                print(f"Subfolder '{layer_folder}' already exists.")
            else:
                file_metadata = {
                    'name': layer_folder,
                    'mimeType': 'application/vnd.google-apps.folder',
                    'parents': [subfolder_id]
                }
                layer_folder_created = drive_service.files().create(body=file_metadata, fields='id, name').execute()
                subfolder_ids[subfolder][f'layer {l}'] = layer_folder_created['id']
                print(f"Subfolder '{layer_folder}' created.")

    return subfolder_ids

PHALANGE_FOLDERS = setup_drive_folders()

def upload_file_to_drive(file_path, folder_id):
    file_metadata = {
        'name': os.path.basename(file_path),
        'parents': [folder_id]
    }
    media = MediaFileUpload(file_path, resumable=True)
    file = drive_service.files().create(body=file_metadata, media_body=media, fields='id').execute()
    print(f"File {file_path} uploaded to Google Drive folder {folder_id}")
    return file['id']

def delete_files_from_drive(folder_id):
    query = f"'{folder_id}' in parents and trashed=false"
    results = drive_service.files().list(q=query, fields="files(id)").execute()
    items = results.get('files', [])
    for item in items:
        file_id = item['id']
        drive_service.files().delete(fileId=file_id).execute()
        print(f"File {file_id} deleted from Google Drive")

def capture_and_store_palm_image(palm_image):
    cv2.imwrite(stored_palmprint_path, palm_image)
    print(f"Stored new palm image at {stored_palmprint_path}")
    return stored_palmprint_path

def authenticate_user(cap):
    global first_palm_stored
    successful_auth_count = 0
    total_attempts = 100

    print("Waiting for 2 seconds before capturing the palm image...")
    time.sleep(2)

    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands_auth.process(img_rgb)

        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                h, w, c = frame.shape
                palm_box = [
                    int(min([landmark.x for landmark in hand_landmarks.landmark]) * w),
                    int(min([landmark.y for landmark in hand_landmarks.landmark]) * h),
                    int(max([landmark.x for landmark in hand_landmarks.landmark]) * w),
                    int(max([landmark.y for landmark in hand_landmarks.landmark]) * h),
                ]
                palm_image = frame[palm_box[1]:palm_box[3], palm_box[0]:palm_box[2]]

                if palm_image.size > 0:
                    stored_palmprint_path = capture_and_store_palm_image(palm_image)
                    first_palm_stored = True
                    break

        if first_palm_stored:
            break

    for attempt in range(total_attempts):
        ret, frame = cap.read()
        if not ret:
            continue

        img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands_auth.process(img_rgb)

        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                h, w, c = frame.shape
                palm_box = [
                    int(min([landmark.x for landmark in hand_landmarks.landmark]) * w),
                    int(min([landmark.y for landmark in hand_landmarks.landmark]) * h),
                    int(max([landmark.x for landmark in hand_landmarks.landmark]) * w),
                    int(max([landmark.y for landmark in hand_landmarks.landmark]) * h),
                ]
                palm_image = frame[palm_box[1]:palm_box[3], palm_box[0]:palm_box[2]]

                if palm_image.size > 0:
                    temp_palmprint_path = os.path.join(STORED_PALMPRINT_DATA_DIR, f"temp_palm_{attempt}.bmp")
                    cv2.imwrite(temp_palmprint_path, palm_image)

                    captured_palmprint_code = encoder.encode_using_file(temp_palmprint_path)
                    stored_palmprint_code = encoder.encode_using_file(stored_palmprint_path)
                    similarity_score = captured_palmprint_code.compare_to(stored_palmprint_code)

                    print(f"Attempt {attempt + 1}: Similarity Score = {similarity_score}")

                    if similarity_score > 0.01:
                        successful_auth_count += 1

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    if successful_auth_count >= 85:
        print("Authentication Successful")
        return True
    else:
        print("Authentication Failed")
        return False

def gesture_recognition():
    global cooldown_end_time, use_google_drive_storage, layer
    cooldown_end_time = 0
    global switch_cooldown_end_time, left_switch_area, cursor_leave_time
    switch_cooldown_end_time = 0
    boxes = []
    use_google_drive_storage = True
    switch_radius = 20
    cursor_stationary_time = 2
    cursor_leave_time = None
    center_point = None
    last_cursor_position = None
    stationary_start_time = None
    movement_threshold = 20
    switch_cooldown_end_time = time.time()
    left_switch_area = False

    def draw_boxes(cursor_window, boxes):
        for box in boxes:
            x, y, color = box
            cv2.rectangle(cursor_window, (x, y), (x + box_size, y + box_size), color, -1)

    cap1 = cv2.VideoCapture(0)

    cap1.set(cv2.CAP_PROP_FRAME_WIDTH, 3840)
    cap1.set(cv2.CAP_PROP_FRAME_HEIGHT, 2160)
    cap2 = cv2.VideoCapture(1) 

    if not authenticate_user(cap2):
        print("Authentication failed. Exiting...")
        cap1.release()
        cap2.release()
        cv2.destroyAllWindows()
        return

    print("Authentication successful. Starting gesture recognition...")

    labels_dict = {
        0: 'point',
        1: 'select 1',
        2: 'select 2',
        3: 'drop 1',
        4: 'drop 2',
        5: 'top of index',
        6: 'middle of index',
        7: 'bottom of index',
        8: 'top of middle',
        9: 'middle of middle',
        10: 'bottom of middle',
        11: 'top of ring',
        12: 'middle of ring',
        13: 'bottom of ring',
        14: 'top of pinky',
        15: 'middle of pinky',
        16: 'bottom of pinky'
    }

    finger_phalanges = {
        'Pinky': [mp_hands.HandLandmark.PINKY_TIP,
                  mp_hands.HandLandmark.PINKY_PIP,
                  mp_hands.HandLandmark.PINKY_MCP],
        'Ring Finger': [mp_hands.HandLandmark.RING_FINGER_TIP,
                        mp_hands.HandLandmark.RING_FINGER_PIP,
                        mp_hands.HandLandmark.RING_FINGER_MCP],
        'Middle Finger': [mp_hands.HandLandmark.MIDDLE_FINGER_TIP,
                          mp_hands.HandLandmark.MIDDLE_FINGER_PIP,
                          mp_hands.HandLandmark.MIDDLE_FINGER_MCP],
        'Index Finger': [mp_hands.HandLandmark.INDEX_FINGER_TIP,
                         mp_hands.HandLandmark.INDEX_FINGER_PIP,
                         mp_hands.HandLandmark.INDEX_FINGER_MCP]
    }

    finger_priority = ['Index Finger', 'Middle Finger', 'Ring Finger', 'Pinky']
    phalange_parts = {0: "top of", 1: "middle of", 2: "bottom of"}

    gesture_to_folder = {
        'top of index': 'phalange 1',
        'middle of index': 'phalange 2',
        'bottom of index': 'phalange 3',
        'top of middle': 'phalange 4',
        'middle of middle': 'phalange 5',
        'bottom of middle': 'phalange 6',
        'top of ring': 'phalange 7',
        'middle of ring': 'phalange 8',
        'bottom of ring': 'phalange 9',
        'top of pinky': 'phalange 10',
        'middle of pinky': 'phalange 11',
        'bottom of pinky': 'phalange 12'
    }

    state = 0
    last_gesture = None
    gesture_start_time = None
    last_gesture_time = time.time()
    gesture_start_times = {i: None for i in range(5, 17)}
    required_activation_time = 1
    threshold = 0.1
    drop_state = 0
    drop_pending = False

    cursor_window = np.zeros((480, 640, 3), dtype=np.uint8)

    box_size = 50
    box1_x, box1_y = random.randint(0, 590), random.randint(0, 430)
    box2_x, box2_y = random.randint(0, 590), random.randint(0, 430)
    box3_x, box3_y = random.randint(0, 590), random.randint(0, 430)
    box1_visible = True
    box2_visible = True
    box3_visible = False
    box3_activated = False
    box1_activated = False
    box2_activated = False
    finger_storage = [None] * 17
    picked_box = None
    box_picked = False
    last_finger_use_time = {i: 0 for i in range(5, 17)}
    gesture_cooldown = 0.5
    placing = False

    cursor_x, cursor_y = None, None
    two_hands_detected = False

    box_points = []

    def toggle_box_visibility():
        global box_visible
        box_visible = not box_visible

    swipe_start_time = None
    swipe_detected = False

    current_cap = cap1

    while True:
        ret, frame = current_cap.read()
        if not ret:
            continue

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands_gesture.process(frame_rgb)

        if not results.multi_hand_landmarks:
            if current_cap == cap1:
                current_cap = cap2
            else:
                current_cap = cap1
            continue

        H, W, _ = frame.shape
        cursor_window = np.zeros((480, 640, 3), dtype=np.uint8)

        if box1_visible:
            if not box1_activated:
                cv2.rectangle(cursor_window, (box1_x, box1_y), (box1_x + box_size, box1_y + box_size), (255, 255, 255), -1)
                cv2.putText(cursor_window, 'Adham', (box1_x, box1_y + box_size + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
            if box1_activated:
                cv2.rectangle(cursor_window, (box1_x, box1_y), (box1_x + box_size, box1_y + box_size), (0, 0, 255), -1)
                box2_activated = False

        if box2_visible:
            if not box2_activated:
                cv2.rectangle(cursor_window, (box2_x, box2_y), (box2_x + box_size, box2_y + box_size), (255, 255, 255), -1)
                cv2.putText(cursor_window, 'Test', (box2_x, box2_y + box_size + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
            if box2_activated:
                cv2.rectangle(cursor_window, (box2_x, box2_y), (box2_x + box_size, box2_y + box_size), (0, 0, 255), -1)
                box1_activated = False
        if box3_visible:
            if not box3_activated:
                cv2.rectangle(cursor_window, (box3_x, box3_y), (box3_x + box_size, box3_y + box_size), (255, 255, 255), -1)
                cv2.putText(cursor_window, 'New Box', (box3_x, box3_y + box_size + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
            if box3_activated:
                cv2.rectangle(cursor_window, (box3_x, box3_y), (box3_x + box_size, box3_y + box_size), (0, 0, 255), -1)
                box1_activated = False
                box2_activated = False

        hand_landmarks_list = results.multi_hand_landmarks

        if len(hand_landmarks_list) == 2:
            two_hands_detected = True

        for hand_landmarks in hand_landmarks_list:
            mp_drawing.draw_landmarks(
                frame, hand_landmarks, mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style())

        if len(hand_landmarks_list) == 1:
            hand_landmarks = hand_landmarks_list[0]
            x_ = [landmark.x for landmark in hand_landmarks.landmark]
            y_ = [landmark.y for landmark in hand_landmarks.landmark]

            data_aux = [(x - min(x_), y - min(y_)) for x, y in zip(x_, y_)]
            data_flat = [item for sublist in data_aux for item in sublist]

            prediction = model.predict([np.array(data_flat)])
            gesture_detected = labels_dict[int(prediction[0])]

            if gesture_detected == 'point':
                cursor_x, cursor_y = int(np.mean(x_) * W), int(np.mean(y_) * H)
                box_points.append((cursor_x, cursor_y))
                if len(box_points) > 4:
                    box_points.pop(0)
                if len(box_points) == 4 and np.linalg.norm(np.array(box_points[0]) - np.array(box_points[3])) < 50:
                    current_cursor_position = (cursor_x, cursor_y)
                    current_time = time.time()

                    if last_cursor_position is None or np.linalg.norm(
                            np.array(current_cursor_position) - np.array(last_cursor_position)) > movement_threshold:
                        last_cursor_position = current_cursor_position
                        stationary_start_time = current_time

                    if current_time - stationary_start_time >= cursor_stationary_time:
                        if center_point is None:
                            center_point = current_cursor_position
                            print(f"New center point defined at {center_point}")

                    if center_point is not None:
                        distance_from_center = np.linalg.norm(
                            np.array(current_cursor_position) - np.array(center_point))
                        if distance_from_center > switch_radius:
                            if cursor_leave_time is None:
                                cursor_leave_time = current_time
                                left_switch_area = True
                        else:
                            cursor_leave_time = None

                            if left_switch_area and current_time - stationary_start_time >= cursor_stationary_time:
                                if current_time >= switch_cooldown_end_time:
                                    use_google_drive_storage = not use_google_drive_storage
                                    print(f"Switched to {'Google Drive' if use_google_drive_storage else 'Local'} storage mode")
                                    switch_cooldown_end_time = current_time + 5
                                    box_points = []
                                    center_point = None
                                    cursor_leave_time = None
                                    stationary_start_time = None
                                    last_cursor_position = None
                                    left_switch_area = False

            if gesture_detected in ['point', 'select 1', 'select 2', 'drop 1', 'drop 2']:
                cv2.putText(frame, f"Gesture: {gesture_detected}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

                if cursor_x is not None and cursor_y is not None:
                    cv2.circle(cursor_window, (cursor_x, cursor_y), 10, (0, 0, 255), -1)

                if cursor_x is not None and cursor_y is not None:
                    if box1_x <= cursor_x <= box1_x + box_size and box1_y <= cursor_y <= box1_y + box_size and box1_visible:
                        if box1_start_time is None:
                            box1_start_time = time.time()
                        elif time.time() - box1_start_time >= 3:
                            box1_activated = True
                    else:
                        box1_start_time = None

                    if box2_x <= cursor_x <= box2_x + box_size and box2_y <= cursor_y <= box2_y + box_size and box2_visible:
                        if box2_start_time is None:
                            box2_start_time = time.time()
                        elif time.time() - box2_start_time >= 3:
                            box2_activated = True
                    else:
                        box2_start_time = None

                current_time = time.time()
                if gesture_detected != last_gesture:
                    last_gesture = gesture_detected
                    last_gesture_time = current_time

                if current_time - last_gesture_time >= 0.5:
                    if gesture_detected == 'select 1' and state == 0:
                        state = 1
                    elif gesture_detected == 'select 2' and state == 1 and not box_picked:
                        if box1_activated:
                            picked_box = 'box1'
                            box1_visible = False
                            box2_activated = False
                            box2_visible = True
                            box_picked = True
                            print('box1 picked up')
                        if box2_activated:
                            picked_box = 'box2'
                            box2_visible = False
                            box1_activated = False
                            box1_visible = True
                            box_picked = True
                            print('box2 picked up')

                        state = 0

        if len(hand_landmarks_list) == 2 and current_cap != cap2:
            left_hand = hand_landmarks_list[0]
            right_hand = hand_landmarks_list[1]

            left_index_tip = left_hand.landmark[mp_hands.HandLandmark.INDEX_FINGER_TIP]

            detected_touch = None
            for finger_name in finger_priority:
                phalanges = finger_phalanges[finger_name]
                for i, phalange_landmark in enumerate(phalanges):
                    fingertip = right_hand.landmark[phalange_landmark]

                    distance = np.linalg.norm([
                        left_index_tip.x - fingertip.x,
                        left_index_tip.y - fingertip.y,
                        left_index_tip.z - fingertip.z
                    ])

                    if distance < threshold:
                        detected_touch = (finger_name, phalange_parts[i], fingertip)
                        break
                if detected_touch:
                    break

            if detected_touch:
                finger_name, phalange_part, fingertip = detected_touch

                x1 = int(min(left_index_tip.x, fingertip.x) * W) - 10
                y1 = int(min(left_index_tip.y, fingertip.y) * H) - 10
                x2 = int(max(left_index_tip.x, fingertip.x) * W) + 10
                y2 = int(max(left_index_tip.y, fingertip.y) * H) + 10

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, f'Touching {phalange_part} {finger_name.lower()}', (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2, cv2.LINE_AA)

                gesture_detected = f'{phalange_part} {finger_name.split()[0].lower()}'

                current_time = time.time()
                if gesture_detected != last_gesture:
                    last_gesture = gesture_detected
                    gesture_start_time = current_time

                if gesture_detected in labels_dict.values():
                    cursor_x, cursor_y = int(np.mean([left_index_tip.x, fingertip.x]) * W), int(
                        np.mean([left_index_tip.y, fingertip.y]) * H)
                    cv2.circle(cursor_window, (cursor_x, cursor_y), 10, (0, 0, 255), -1)

                    if box1_x <= cursor_x <= box1_x + box_size and box1_y <= cursor_y <= box1_y + box_size and box1_visible:
                        if box1_start_time is None:
                            box1_start_time = current_time
                        elif current_time - box1_start_time >= 3:
                            box1_activated = True
                    else:
                        box1_start_time = None

                    if box2_x <= cursor_x <= box2_x + box_size and box2_y <= cursor_y <= box2_y + box_size and box2_visible:
                        if box2_start_time is None:
                            box2_start_time = current_time
                        elif current_time - box2_start_time >= 3:
                            box2_activated = True
                    else:
                        box2_start_time = None

                    if gesture_detected != last_gesture:
                        last_gesture = gesture_detected
                        last_gesture_time = current_time

                    if current_time - last_gesture_time >= 0.5:
                        if gesture_detected == 'select 1' and state == 0:
                            state = 1
                        elif gesture_detected == 'select 2' and state == 1 and not box_picked:
                            if box1_activated:
                                picked_box = 'box1'
                                box1_visible = False
                                box2_activated = False
                                box2_visible = True
                                box_picked = True
                                print('box1 picked up')
                            if box2_activated:
                                picked_box = 'box2'
                                box2_visible = False
                                box1_activated = False
                                box1_visible = True
                                box_picked = True
                                print('box2 picked up')

                            state = 0

                        finger_gestures = ['top of index', 'middle of index', 'bottom of index',
                                           'top of middle', 'middle of middle', 'bottom of middle',
                                           'top of ring', 'middle of ring', 'bottom of ring',
                                           'top of pinky', 'middle of pinky', 'bottom of pinky']

                        if gesture_detected in finger_gestures:
                            finger_index = finger_gestures.index(
                                gesture_detected) + 5
                            current_time = time.time()

                            if current_time >= cooldown_end_time:
                                if picked_box:
                                    if gesture_start_times[finger_index] is None:
                                        gesture_start_times[finger_index] = current_time

                                    if current_time - gesture_start_times[finger_index] >= 1:
                                        if use_google_drive_storage:
                                            folder_id = PHALANGE_FOLDERS[gesture_to_folder[gesture_detected]][f'layer {layer}']
                                            query = f"'{folder_id}' in parents and trashed=false"
                                            results = drive_service.files().list(q=query, fields="files(id)").execute()
                                            items = results.get('files', [])

                                            if not items:
                                                print(f"Placing {picked_box} in {gesture_to_folder[gesture_detected]} in layer {layer}")
                                                upload_file_to_drive(
                                                    ADHAM_FILE_PATH if picked_box == 'box1' else TEST_FILE_PATH,
                                                    folder_id)
                                                picked_box = None
                                                box2_activated = False
                                                box1_activated = False
                                                box_picked = False
                                                cooldown_end_time = current_time + 15
                                            else:
                                                print(f"{gesture_to_folder[gesture_detected]} in layer {layer} is full")
                                        else:
                                            if finger_storage[finger_index] is None:
                                                finger_storage[finger_index] = picked_box
                                                print(f'{picked_box} placed in {gesture_to_folder[gesture_detected]} in layer {layer}')
                                                picked_box = None
                                                box2_activated = False
                                                box1_activated = False
                                                box_picked = False
                                                cooldown_end_time = current_time + 5
                                            else:
                                                print(f"{gesture_to_folder[gesture_detected]} in layer {layer} is full")
                                        gesture_start_times[finger_index] = None
                                else:
                                    if use_google_drive_storage:
                                        folder_id = PHALANGE_FOLDERS[gesture_to_folder[gesture_detected]][f'layer {layer}']
                                        query = f"'{folder_id}' in parents and trashed=false"
                                        results = drive_service.files().list(q=query, fields="files(id)").execute()
                                        items = results.get('files', [])
                                        if items:
                                            print("Data is ready to be dropped")
                                            drop_pending = True
                                        else:
                                            print(f"{gesture_to_folder[gesture_detected]} in layer {layer} is empty")
                                    else:
                                        if finger_storage[finger_index] is not None:
                                            print("Data is ready to be dropped")
                                            drop_pending = True
                                        else:
                                            print("Neither picked_box nor finger_storage condition met")
                            else:
                                print("Cooldown active, ignoring gestures")

                        else:
                            for index in range(5, 17):
                                gesture_start_times[index] = None

                        if last_gesture != gesture_detected:
                            for index in range(5, 17):
                                if finger_gestures[index - 5] == last_gesture:
                                    gesture_start_times[index] = None

                        last_gesture = gesture_detected

        if drop_pending:
            if gesture_detected == 'drop 1' and drop_state == 0:
                drop_state = 1
                print("Drop state 1 activated")
            elif gesture_detected == 'drop 2' and drop_state == 1:
                drop_state = 2
                print("Drop state 2 activated")

            if drop_state == 2:
                if use_google_drive_storage:
                    for index in range(5, 17):
                        folder_id = PHALANGE_FOLDERS[gesture_to_folder[labels_dict[index]]][f'layer {layer}']
                        query = f"'{folder_id}' in parents and trashed=false"
                        results = drive_service.files().list(q=query, fields="files(id)").execute()
                        items = results.get('files', [])
                        if items:
                            new_box_x = (cursor_window.shape[1] - box_size) // 2
                            new_box_y = (cursor_window.shape[0] - box_size) // 2

                            box3_x, box3_y = new_box_x, new_box_y
                            box3_visible = True

                            delete_files_from_drive(folder_id)
                            print(
                                f'New box spawned at ({new_box_x}, {new_box_y}) and files removed from {gesture_to_folder[labels_dict[index]]} in layer {layer}')
                else:
                    for index in range(5, 17):
                        if finger_storage[index] is not None:
                            new_box_x = (cursor_window.shape[1] - box_size) // 2
                            new_box_y = (cursor_window.shape[0] - box_size) // 2

                            box3_x, box3_y = new_box_x, new_box_y
                            box3_visible = True

                            finger_storage[index] = None
                            print(
                                f'New box spawned at ({new_box_x}, {new_box_y}) and files removed from {gesture_to_folder[labels_dict[index]]} in layer {layer}')
                drop_state = 0
                drop_pending = False

        if two_hands_detected and cursor_x is not None and cursor_y is not None:
            cv2.circle(cursor_window, (cursor_x, cursor_y), 10, (0, 0, 255), -1)

        if len(hand_landmarks_list) == 2:
            left_hand = hand_landmarks_list[0]
            right_hand = hand_landmarks_list[1]

            left_hand_pos = left_hand.landmark[mp_hands.HandLandmark.WRIST]
            right_hand_pos = right_hand.landmark[mp_hands.HandLandmark.WRIST]

            if swipe_start_time is None:
                swipe_start_time = time.time()

            if abs(left_hand_pos.x - right_hand_pos.x) < 0.2 and abs(left_hand_pos.y - right_hand_pos.y) < 0.2:
                if not swipe_detected:
                    swipe_detected = True
                    swipe_start_time = time.time()
            else:
                if swipe_detected and time.time() - swipe_start_time < 1.0:
                    layer += 1
                    if layer > 2:
                        layer = 1
                    print(f"Layer changed to {layer}")
                swipe_detected = False
                swipe_start_time = None

        cv2.putText(frame, f"Layer: {layer}", (W - 150, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        cv2.imshow('Cursor', cursor_window)
        cv2.imshow('Gesture Recognition', frame)
        cursor_window = np.zeros((480, 640, 3), dtype=np.uint8)
        draw_boxes(cursor_window, boxes)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('l'):
            use_google_drive_storage = not use_google_drive_storage
            print(f"Switched to {'Google Drive' if use_google_drive_storage else 'Local'} storage mode")

    cap1.release()
    cap2.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    gesture_recognition()
