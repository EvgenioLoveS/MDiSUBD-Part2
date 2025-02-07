CREATE OR REPLACE FUNCTION Calculate_Annual_Compensation (
    p_salary IN NUMBER,  -- Месячная зарплата
    p_bonus_percent IN NUMBER  -- Процент премии
) RETURN NUMBER IS
    v_total_reward NUMBER;  -- Общее вознаграждение
BEGIN
    -- Проверка на правильность ввода зарплаты
    IF p_salary IS NULL OR p_salary <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Зарплата должна быть положительным числом');
    END IF;

    -- Проверка на правильность ввода процента премиальных
    IF p_bonus_percent IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Процент премиальных не может быть пустым');
    ELSIF p_bonus_percent < 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Процент премиальных не может быть отрицательным');
    END IF;

    -- Вычисление общего вознаграждения
    v_total_reward := (1 + p_bonus_percent / 100) * 12 * p_salary;

    RETURN v_total_reward;
END;
/
