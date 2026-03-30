import cv2
import os

# 영상 파일 경로 설정(업로드된 영상 위치) - 변경필요*(백엔드와 같이 변경)
video_path = "uploads/video.mp4"
# 프레임 저장 폴더 생성
output_folder = "frames"

# 영상 이름 기준 폴더 생성
video_name = os.path.splitext(os.path.basename(video_path))[0]
output_folder = f"frames/{video_name}"
os.makedirs(output_folder, exist_ok=True)

#영상 열기
cap = cv2.VideoCapture(video_path)
if not cap.isOpened():
    print("영상 파일을 열 수 없습니다.")
    exit()

#FPS 정보 가져오기
fps = int(cap.get(cv2.CAP_PROP_FPS))
if fps == 0:
    fps = 30

frame_count = 0

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # 1초당 1프레임 저장
    if frame_count % fps == 0:
        filename = f"{output_folder}/frame_{frame_count}.jpg"
        cv2.imwrite(filename, frame)

    frame_count += 1

cap.release()

print("프레임 추출 완료")