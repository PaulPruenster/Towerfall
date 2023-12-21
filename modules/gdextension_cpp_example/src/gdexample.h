#ifndef GDEXAMPLE_H
#define GDEXAMPLE_H

#include <godot_cpp/classes/sprite2d.hpp>
#define MAX_WIIMOTES				4

namespace godot {

class GDExample : public Sprite2D {
	GDCLASS(GDExample, Sprite2D)

private:
	double time_passed;
	double amplitude;

protected:
	static void _bind_methods();

public:
	double get_amplitude() const;
	void set_amplitude(const double p_amplitude);
	void connect_wii();
	GDExample();
	~GDExample();
	void _process(double delta) override;


};

}

#endif