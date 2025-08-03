#include <iostream>

extern "C" const char* get_best_title(const char* scene_path);

int main() {
    const char* resultado = get_best_title("scene.jpeg");
    std::cout << "Melhor azulejo: " << resultado << std::endl;
    return 0;
}