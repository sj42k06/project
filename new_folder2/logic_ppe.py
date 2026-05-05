# 보호구 착용 여부 판별 로직
def is_inside(person_bbox, obj_bbox, margin=20):
    #사람의 바운딩 박스 범위 내에 보호구(안전모/조끼)의 중심점이 있는지 확인합니다.
    #통합 모델의 특성을 고려하여 마진(margin)을 기존 15에서 20으로 살짝 넓혔습니다.
    
    px1, py1, px2, py2 = person_bbox
    ox1, oy1, ox2, oy2 = obj_bbox
    
    # 객체(안전모/조끼)의 중심점 계산
    ocx, ocy = (ox1 + ox2) // 2, (oy1 + oy2) // 2
    
    # 사람 바운딩 박스 범위 내에 중심점이 있는지 확인
    return (px1 - margin <= ocx <= px2 + margin) and (py1 - margin <= ocy <= py2 + margin)

def analyze_ppe(structured_frames):
    
    #미착용(NO-) 클래스가 없는 통합 모델 환경에 맞춰 착용 여부를 분석합니다.
    
    results = []
    for frame in structured_frames:
        frame_result = {"frame": frame["frame"], "workers": []}
        
        for person in frame["persons"]:
            # 1. 안전모 착용 여부 판별
            # 사람 영역 안에 'hardhat' 상태를 가진 객체가 하나라도 있으면 착용으로 간주
            has_helmet = any(h["status"] == "hardhat" for h in frame["helmets"] if is_inside(person["bbox"], h["bbox"]))
            
            # 2. 안전조끼 착용 여부 판별
            # 사람 영역 안에 'safety vest' 상태를 가진 객체가 하나라도 있으면 착용으로 간주
            has_vest = any(v["status"] == "safety vest" for v in frame["vests"] if is_inside(person["bbox"], v["bbox"]))

            # 3. 상태 확정 로직 (미착용 클래스 조건 삭제)
            # 클래스가 발견되면 HELMET, 발견되지 않으면 NO_HELMET
            helmet_status = "HELMET" if has_helmet else "NO_HELMET"
            vest_status = "VEST" if has_vest else "NO_VEST"
            
            # 4. 위험도 산정
            risk = "LOW"
            if helmet_status == "NO_HELMET": 
                risk = "HIGH"
            elif vest_status == "NO_VEST": 
                risk = "MEDIUM"

            frame_result["workers"].append({
                "bbox": person["bbox"], 
                "fx": person["fx"], 
                "fy": person["fy"],
                "helmet": helmet_status, 
                "vest": vest_status, 
                "risk": risk
            })
        results.append(frame_result)
    return results