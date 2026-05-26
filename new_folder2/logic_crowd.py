import math

# AI/데이터 분석 환경에서 널리 쓰이는 scikit-learn 탐지 시 클러스터링 활용
try:
    import numpy as np
    from sklearn.cluster import DBSCAN
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False

# ==============================================================================
# [스케일 행렬 변환 및 좌표 투영 함수]
# logic_collision.py와 완전히 동일한 메커니즘을 사용하여 일관성을 확보합니다.
# ==============================================================================
def get_scale_matrix(pixel_per_meter=100):
    """
    1미터가 몇 픽셀인지(pixel_per_meter)를 바탕으로 
    픽셀 좌표를 미터(m) 공간으로 축소해주는 변환 행렬을 생성합니다.
    """
    scale = 1.0 / pixel_per_meter
    return np.array([[scale, 0, 0], [0, scale, 0], [0, 0, 1]], dtype='float32')

def transform_point(x, y, matrix):
    """
    행렬 곱 연산을 통해 (x, y) 픽셀 좌표를 실제 미터(m) 단위 좌표로 변환합니다.
    """
    p = np.array([x, y, 1], dtype='float32')
    tp = np.dot(matrix, p)
    if tp[2] != 0: 
        tp /= tp[2]
    return float(tp[0]), float(tp[1])


def analyze_crowd_dbscan(persons_with_meters, distance_threshold, min_people_limit):
    """
    DBSCAN 알고리즘을 사용해 미터(m) 단위로 변환된 공간에서 밀집 그룹을 정확하게 식별합니다.
    """
    num_persons = len(persons_with_meters)
    if num_persons < min_people_limit:
        return False, 0, [-1] * num_persons

    # 스케일 행렬로 변환 완료된 실제 미터(m) 좌표 활용
    coordinates = np.array([[p["real_x"], p["real_y"]] for p in persons_with_meters])
    
    # eps: 같은 밀집 그룹으로 판단할 최대 실제 거리 (단위: 미터, 예: 2.0m)
    # min_samples: 하나의 밀집 그룹을 형성하기 위한 최소 인원수 (예: 5명)
    db = DBSCAN(eps=distance_threshold, min_samples=min_people_limit).fit(coordinates)
    labels = db.labels_  # 각 사람별 그룹 ID 할당 (-1은 밀집되지 않은 노이즈)
    
    unique_labels = set(labels)
    if -1 in unique_labels:
        unique_labels.remove(-1)
        
    crowd_alert = len(unique_labels) > 0
    crowd_groups_count = len(unique_labels)
    
    # JSON 직렬화 호환성을 위해 정수형으로 변환하여 반환
    return crowd_alert, crowd_groups_count, [int(x) for x in labels]


def analyze_crowd_pure_python(persons_with_meters, distance_threshold, min_people_limit):
    """
    scikit-learn 라이브러리가 없을 때 작동하는 미터(m) 단위 기하 거리 연산 백업 함수입니다.
    """
    num_persons = len(persons_with_meters)
    crowd_status_list = []
    
    # 변환된 미터 좌표 간의 유클리드 거리를 전수조사
    for i, p1 in enumerate(persons_with_meters):
        close_people_count = 0
        for j, p2 in enumerate(persons_with_meters):
            if i == j:
                continue
            # 픽셀이 아닌 실제 미터 단위 값으로 거리 연산
            dist = math.sqrt((p1["real_x"] - p2["real_x"])**2 + (p1["real_y"] - p2["real_y"])**2)
            if dist <= distance_threshold:
                close_people_count += 1
        
        # 본인을 포함하여 설정한 기준 인원 이상이 근접해 있다면 밀집으로 판단
        is_crowded = (close_people_count + 1) >= min_people_limit
        crowd_status_list.append(is_crowded)
        
    crowd_alert = any(crowd_status_list)
    return crowd_alert, crowd_status_list


def analyze_crowd_density(structured_frames, pixel_per_meter=100, safe_distance_m=2.0, min_people_limit=5):
    """
    structure_ppe.py의 출력 데이터 포낸을 입력받아 프레임별 인원 밀집 상황을 분석합니다.
    
    Args:
        structured_frames (list): structure_data() 함수가 반환한 구조화 데이터
        pixel_per_meter (int): 1미터당 차지하는 픽셀 수 (기본값: 100px = 1m)
        safe_distance_m (float): 밀집 상황으로 판단할 작업자 간의 최대 실제 물리 거리 (미터 단위, 기본값: 2.0m)
        min_people_limit (int): 경보(Alert)를 발령할 최소 밀집 인원수 기준 (기본값: 5명)
    """
    # logic_collision.py의 가중치 행렬 생성 방식을 그대로 가져옴
    H_matrix = get_scale_matrix(pixel_per_meter)
    results = []
    
    for frame in structured_frames:
        frame_result = {
            "frame": frame["frame"],
            "crowd_alert": False,       # 해당 프레임에 밀집 경보가 발생했는지 여부
            "crowd_groups_count": 0,    # 발견된 밀집 그룹의 총 개수
            "workers": []
        }
        
        persons = frame.get("persons", [])
        
        # 1. 모든 작업자의 발끝 픽셀 좌표를 스케일 행렬을 통해 미터 단위 좌표로 일괄 전처리 변환
        persons_with_meters = []
        for person in persons:
            rx, ry = transform_point(person["fx"], person["fy"], H_matrix)
            
            # 기존 딕셔너리를 보존하면서 미터 좌표 정보 추가 bind
            person_copied = person.copy()
            person_copied["real_x"] = rx
            person_copied["real_y"] = ry
            persons_with_meters.append(person_copied)
        
        if HAS_SKLEARN:
            # 1. DBSCAN 알고리즘 모드 (미터 평면 연산 적용)
            alert, groups_count, labels = analyze_crowd_dbscan(persons_with_meters, safe_distance_m, min_people_limit)
            frame_result["crowd_alert"] = alert
            frame_result["crowd_groups_count"] = groups_count
            
            for idx, person in enumerate(persons_with_meters):
                is_crowded = labels[idx] != -1
                frame_result["workers"].append({
                    "bbox": person["bbox"],
                    "fx": person["fx"],
                    "fy": person["fy"],
                    "is_crowded": is_crowded,
                    "crowd_group_id": labels[idx] if is_crowded else None
                })
        else:
            # 2. 호환성 모드 (Pure Python 미터 평면 연산 적용)
            alert, crowd_status_list = analyze_crowd_pure_python(persons_with_meters, safe_distance_m, min_people_limit)
            frame_result["crowd_alert"] = alert
            
            for idx, person in enumerate(persons_with_meters):
                frame_result["workers"].append({
                    "bbox": person["bbox"],
                    "fx": person["fx"],
                    "fy": person["fy"],
                    "is_crowded": crowd_status_list[idx],
                    "crowd_group_id": None
                })
                
        results.append(frame_result)
        
    return results