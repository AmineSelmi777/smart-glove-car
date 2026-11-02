from ml.speed import Calibration, Ema, flex_to_speed

C = Calibration(open=3200, closed=3900)


def test_main_ouverte_vitesse_max():
    assert flex_to_speed(3200, C) == 255


def test_poing_ferme_arret():
    assert flex_to_speed(3900, C) == 0


def test_hors_plage_est_borne():
    assert flex_to_speed(0, C) == 255
    assert flex_to_speed(4095, C) == 0


def test_vitesse_decroit_avec_la_flexion():
    vitesses = [flex_to_speed(v, C) for v in range(3200, 3901, 50)]
    assert vitesses == sorted(vitesses, reverse=True)


def test_filtre_lisse():
    f = Ema(alpha=0.5)
    assert f.update(100) == 100
    assert f.update(200) == 150