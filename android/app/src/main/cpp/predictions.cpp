#include <opencv2/opencv.hpp>
#include <opencv2/features2d.hpp>
#include <filesystem>
#include <iostream>
#include <cstring>
#include <string> // Adicionado para std::string
#include <android/log.h>

#define LOG_TAG "DetectorCPP"

namespace fs = std::filesystem;

extern "C" __attribute__((visibility("default"))) __attribute__((used))
const char* get_best_title(const char* scene_path, const char* azulejos_dir_path) {
    // É mais seguro retornar uma string estática para evitar problemas de memória
    static std::string result_str = "not_found";
    std::string azulejo_dir = std::string(azulejos_dir_path);

    // LOG: Avisa que a função começou
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Iniciando detecção. Cena: %s", scene_path);

    cv::Mat img_scene = cv::imread(scene_path, cv::IMREAD_GRAYSCALE);
    if (img_scene.empty()) {
        // ANTES: std::cerr << "Erro: cena inválida!" << std::endl;
        // DEPOIS:
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "Erro: Imagem da cena está vazia ou não foi encontrada no caminho: %s", scene_path);
        result_str = "ERRO_CENA_INVALIDA";
        return result_str.c_str();
    }

    // ANTES: std::cout << "Procurando azulejos em: " << azulejo_dir << std::endl;
    // DEPOIS:
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Procurando azulejos em: %s", azulejo_dir.c_str());

    auto sift = cv::SIFT::create();
    std::vector<cv::KeyPoint> kp_scene;
    cv::Mat desc_scene;
    sift->detectAndCompute(img_scene, cv::noArray(), kp_scene, desc_scene);

    cv::FlannBasedMatcher matcher;

    int best_score = 0;
    std::string best_tile = "not_found";

    for (const auto& entry : fs::directory_iterator(azulejo_dir)) {
        if (!entry.is_regular_file()) continue;

        std::string tile_path = entry.path().string();
        // ANTES: std::cout << "Lendo azulejo: " << tile_path << std::endl;
        // DEPOIS:
        __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, "Processando azulejo: %s", tile_path.c_str());

        cv::Mat img_tile = cv::imread(tile_path, cv::IMREAD_GRAYSCALE);
        if (img_tile.empty()) {
            // ANTES: std::cerr << "Erro ao carregar azulejo: " << tile_path << std::endl;
            // DEPOIS:
            __android_log_print(ANDROID_LOG_WARN, LOG_TAG, "Aviso: Nao foi possivel carregar a imagem do azulejo: %s", tile_path.c_str());
            continue;
        }

        std::vector<cv::KeyPoint> kp_tile;
        cv::Mat desc_tile;
        sift->detectAndCompute(img_tile, cv::noArray(), kp_tile, desc_tile);

        if (desc_tile.empty()) {
             __android_log_print(ANDROID_LOG_WARN, LOG_TAG, "Aviso: Nenhum descritor encontrado para o azulejo: %s", tile_path.c_str());
             continue;
        }

        std::vector<std::vector<cv::DMatch>> knn_matches;
        matcher.knnMatch(desc_tile, desc_scene, knn_matches, 2);

        std::vector<cv::DMatch> good_matches;
        const float ratio_thresh = 0.7f;
        for (size_t i = 0; i < knn_matches.size(); i++) {
            if (knn_matches[i].size() > 1 && knn_matches[i][0].distance < ratio_thresh * knn_matches[i][1].distance) {
                good_matches.push_back(knn_matches[i][0]);
            }
        }

        if ((int)good_matches.size() > best_score) {
            best_score = good_matches.size();
            best_tile = entry.path().filename().string();
            // LOG: Informa sobre um novo melhor resultado encontrado
            __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Novo melhor resultado encontrado: %s com %d bons matches.", best_tile.c_str(), best_score);
        }
    }

    result_str = best_tile;
    // LOG: Informa o resultado final antes de retornar
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "Retornando resultado final: %s", result_str.c_str());
    return result_str.c_str();
}