struct Quaternion
{
    double w;
    Vector3 v;

    void Copy(in Quaternion other)
    {
        w = other.w;
        v = other.v;
    }

    void FromEulerAngle(double yaw, double pitch, double roll)
    {
        double cy = Cos(yaw * 0.5);
        double sy = Sin(yaw * 0.5);
        double cp = Cos(pitch * 0.5);
        double sp = Sin(pitch * 0.5);
        double cr = Cos(roll * 0.5);
        double sr = Sin(roll * 0.5);

        w = cy * cp * cr + sy * sp * sr;
        v.x = cy * cp * sr - sy * sp * cr;
        v.y = sy * cp * sr + cy * sp * cr;
        v.z = sy * cp * cr - cy * sp * sr;
    }

    float, float, float ToEulerAngle()
    {
        // Roll
        double sinRCosP = 2 * (w * v.x + v.y * v.z);
        double cosRCosP = 1 - 2 * (v.x * v.x + v.y * v.y);
        double roll = Atan2(sinRCosP, cosRCosP);

        // Pitch
        double sinP = 2 * (w * v.y - v.z * v.x);
        double pitch;
        if (Abs(sinP) >= 1) pitch = 90 * (sinP < 0 ? -1 : 1);
        else pitch = Asin(sinP);

        // Yaw
        double sinYCosP = 2 * (w * v.z + v.x * v.y);
        double cosYCosP = 1 - 2 * (v.y * v.y + v.z * v.z);
        double yaw = Atan2(sinYCosP, cosYCosP);

        return yaw, pitch, roll;
    }

    void Invert()
    {
        v = -v;
    }

    Vector3 Rotate(Vector3 v)
    {
        Quaternion v4;
        v4.v = v;

        Invert();
        Multiply(v4, v4, self);
        Invert();
        Multiply(v4, self, v4);

        return v4.v;
    }

    static void Add(out Quaternion res, in Quaternion lhs, in Quaternion rhs)
    {
        res.w = lhs.w + rhs.w;
        res.v = lhs.v + rhs.v;
    }

    static void Subtract(out Quaternion res, in Quaternion lhs, in Quaternion rhs)
    {
        res.w = lhs.w - rhs.w;
        res.v = lhs.v - rhs.v;
    }

    static void Scale(out Quaternion res, in double lhs, in Quaternion rhs)
    {
        res.w = lhs * rhs.w;
        res.v = lhs * rhs.v;
    }

    static void Multiply(out Quaternion res, in Quaternion lhs, in Quaternion rhs)
    {
        double lw = lhs.w;
        double rw = rhs.w;

        res.w = rw * lw - rhs.v dot lhs.v;
        res.v = rw * lhs.v + lw * rhs.v + lhs.v cross rhs.v;
    }

    static double DotProduct(in Quaternion lhs, in Quaternion rhs)
    {
        return lhs.w * rhs.w + lhs.v dot rhs.v;
    }

    static void Slerp(out Quaternion res, in Quaternion start, in Quaternion end, double t)
    {
        Quaternion s;
        s.Copy(start);
        Quaternion e;
        e.Copy(end);

        double dp = DotProduct(s, e);

        if (dp < 0)
        {
            Scale(e, -1, e);
            dp *= -1;
        }

        if (dp > 0.9995)
        {
            Subtract(res, e, s);
            Scale(res, t, res);
            Add(res, s, res);
        }
        else
        {
            double theta0 = ACos(dp);
            double theta = t * theta0;
            double sinTheta = Sin(theta);
            double sinTheta0 = Sin(Theta0);

            Scale(s, Cos(theta) - dp * sinTheta / sinTheta0, s);
            Scale(e, sinTheta / sinTheta0, e);
            Add(res, s, e);
        }
    }
}