
# load library ----
library(readxl)
library(matrixStats)
library(openxlsx)
library(dplyr)
library(tidyverse)
library(dplyr)
library(ggplot2)
library(ropls) # requires BiocManager

rm(list=ls(all= T))
setwd('C:/Users/cindy/Github/UG_proj/IBD_project/data/serum')
getwd()

# a. UNTARGETED ----
## 1. prerproecss for PCA ----
getSheetNames('merged_si.xlsm')
s_merged = read_excel('merged_si.xlsm', sheet = 'Inception')
head(s_merged)
colnames(s_merged)

# cleaning
unclean = s_merged
colClean = function(x){ colnames(x) <- gsub("\\s|\\(|\\)|\\'|,|:|\\||\\/|\\;", ".", colnames(x)); x } 
s_merged = colClean(s_merged)
# format
s_merged = s_merged %>% 
  mutate(Disease.type = str_replace_all(Disease.type, 'healthy control', 'Healthy control')) %>%  
  mutate(Disease.type = str_replace_all(Disease.type, 'disease control', 'Disease control')) %>% 
  mutate(Disease.type = str_replace_all(Disease.type, 'Healthy control', 'HC')) %>% 
  mutate(Disease.type = str_replace_all(Disease.type, 'Disease control', 'DC')) %>% 
  mutate(Disease.type = as.factor(Disease.type)) 
# diet and gender
s_merged = s_merged %>% 
  mutate(Diet = case_when(Meat == 1 & Vegetarian == 0 ~ 'Meat', 
                          Meat == 0 & Vegetarian == 1 ~ 'Vegetarian',
                          Meat == 0 & Vegetarian == 0 ~ 'Vegetarian')) %>% 
  select(-Meat) %>% 
  select(-Vegetarian) %>% 
  select(-DOB) %>% 
  mutate(Diet = as.factor(Diet)) %>%
  mutate(Sex.M.1..or.F.0. = case_when(Sex.M.1..or.F.0. == 1 ~ 'Male',
                                      Sex.M.1..or.F.0. == 0 ~ 'Female')) %>%
  mutate(Sex.M.1..or.F.0. = as.factor(Sex.M.1..or.F.0.))

s_merged[,c(16:590)] = lapply(s_merged[,c(16:590)], as.numeric)

# autoscaling
dim(s_merged)
s_merged_z = s_merged[,16:590]
s_merged[,16:590] = (s_merged_z-rowMeans(s_merged_z))/(rowSds(as.matrix(s_merged_z)))[row(s_merged_z)]
s_merged = s_merged %>% 
  arrange(desc(Disease.type), Sample.check)

## 2. PCA ----
which(is.na(C))
pca_si = prcomp(s_merged[,16:590], scale = FALSE,
                 center = TRUE, retx = T)
names(pca_si)
summary(pca_si)

# scores plot 
PC1<-pca_si$x[,1]
PC2<-pca_si$x[,2]
ggplot(s_merged, 
       aes(x = PC1, 
           y = PC2, 
           color = Disease.type)) +
  geom_point(size=2) +
  stat_ellipse() + 
  ggtitle('PCA of serum samples from inception') + 
  theme(plot.title = element_text(hjust = 0.5))
ggsave('C:/Users/cindy/Github/UG_proj/IBD_project/output/figures/PCA_serum_i.png', width = 6, height = 6)

# scree plot 
var_explained = pca_si$sdev^2 / sum(pca_si$sdev^2) *100
qplot(c(1:5), var_explained[1:5]) + 
  geom_line() + 
  xlab("Principal Component") + 
  ylab("% of Variance Explained") +
  ggtitle("Scree Plot") +
  ylim(0,100)

ggsave('C:/Users/cindy/Github/UG_proj/IBD_project/output/figures/Scree_serum_i.png', width = 6, height = 6)

## 3. OPLS-DA ----
#class_hcuc = s_merged[s_merged$Disease.type %in% c('UC', 'HC'), ]
class_hcuc = s_merged %>%
  filter(Disease.type %in% c('UC', 'HC')) %>%
  na.omit(~)

data_hcuc = as.matrix(unlist(class_hcuc[,16:590]), nrow = 56, ncol = 575, byrow = TRUE)
opls_hcuc= opls(data_hcuc,class_hcuc$Disease.type, predI = 1, orthoI = 2)
names(s_merged.oplsda)
colnames(class_hcuc)



## 4. univariate analysis ---- 

s_merged_org = s_merged_org %>%  
  mutate(Disease.type_broad = str_replace_all(Disease.type, 
                                      c('CD'='IBD',
                                        'UC'= 'IBD',
                                        'Healthy control'='control',
                                        'Disease control'='control')))

# HC_UC
s_HC_UC = s_merged_org %>% 
  filter(Disease.type %in% c('UC', 'HC')) %>%  
  group_by(Disease.type) %>% 
  select(-c(1,2,4:18,Disease.type_broad ))


HC_UC_ps = lapply(s_HC_UC[-1], function(x) wilcox.test(x ~ s_HC_UC$Disease.type)$p.value)
HC_UC_ps = p.adjust(HC_UC_ps, method = 'BH')
HC_UC_ps = which(HC_UC_ps < 0.05)
x_sorted = sort(unlist(HC_UC_ps), decreasing = FALSE)
data.frame(x_sorted)
format(data.frame(x_sorted),scientific = FALSE)

# HC_CD
s_HC_CD = s_merged_org %>% 
  filter(Disease.type %in% c('CD', 'Healthy control')) %>%  
  group_by(Disease.type) %>% 
  select(-c(1,2,4:18,Disease.type_broad ))


HC_CD_ps = lapply(s_HC_CD[-1], function(x) wilcox.test(x ~ s_HC_CD$Disease.type)$p.value)
x_sorted = sort(unlist(HC_CD_ps), decreasing = FALSE)
data.frame(x_sorted)
format(data.frame(x_sorted),scientific = FALSE)

  #test 
boxplot(DG.18.2.18.1.~ Disease.type, data = s_HC_CD)
s_HC_CD[ 'DG.18.2.18.1.']
class(x_sorted)

# caucasian_IBD only 
s_cau = s_merged_org %>% 
  filter(Disease.type %in% c('CD', 'UC')) %>%  
  group_by(Ethnicity) %>% 
  select(-c(1:9,11:18,Disease.type_broad ))


cau_ps = lapply(s_cau[-1], function(x) wilcox.test(x ~ s_cau$Ethnicity)$p.value)
x_sorted = sort(unlist(cau_ps), decreasing = FALSE)
data.frame(x_sorted)
format(data.frame(x_sorted),scientific = FALSE)

# sex(IBD only)
s_fm = s_merged_org %>% 
  filter(Disease.type %in% c('CD', 'UC')) %>%  
  group_by(Sex.M.1..or.F.0.) %>% 
  select(-c(1:12,14:18 ))


fm_ps = lapply(s_fm[-1], function(x) wilcox.test(x ~ s_fm$Sex.M.1..or.F.0.)$p.value)
x_sorted = sort(unlist(fm_ps), decreasing = FALSE)
data.frame(x_sorted)
format(data.frame(x_sorted),scientific = FALSE)

# DC_UC
s_DC_UC = s_merged_org %>% 
  filter(Disease.type %in% c('Disease control', 'UC')) %>%  
  group_by(Disease.type) %>% 
  select(-c(1,2,4:18))


DC_UC_ps = lapply(s_DC_UC[-1], function(x) wilcox.test(x ~ s_DC_UC$Disease.type)$p.value)
x_sorted = sort(unlist(DC_UC_ps), decreasing = FALSE)
data.frame(x_sorted)
format(data.frame(x_sorted),scientific = FALSE)


## 4. changes names to original ----

setwd('C:/Users/cindy/OneDrive - Imperial College London/Desktop/IBD_project/output')

getSheetNames('meta_p_adj.xlsx')
hcuc = read_excel('meta_p_adj.xlsx', sheet = 's_HC_UC')
dcuc = read_excel('meta_p_adj.xlsx', sheet = 's_DC_UC')

uncol = data.frame(colnames(unclean[19:length(unclean)]))
colnames(s_merged)

#hcuc
tgt = uncol %>% 
  mutate(Primary_ID = colnames(s_merged_z))
hcuc[1]
done = hcuc[1] %>%
  left_join(tgt, by='Primary_ID')

write.table(done[2], "clipboard", sep="\t", row.names=TRUE, col.names=FALSE)

#hc
dcuc[1]
done2 = dcuc[1] %>%
  left_join(tgt, by='Primary_ID')
write.table(done2[2], "clipboard", sep="\t", row.names=TRUE, col.names=FALSE)


# b. EDA UNTARGETED serum  ----
write.table(colnames(s_merged_z), "clipboard", sep="\t", row.names=TRUE, col.names=FALSE)
write.table(colnames(unclean[19:ncol(unclean)]), "clipboard", sep="\t", row.names=TRUE, col.names=FALSE)
#
## 1. lactcer 18:1 16:0----

# LacCer.d18.1.16.0. / LacCer(d18:1/16:0)
s_HC_CD = unclean %>% 
  filter(Disease.type %in% c('HC', 'Healthy control')) %>%  
  group_by(Disease.type) %>% 
  select(-c(1,2,4:18,Disease.type_broad ))

boxplot(LacCer.d18.1.16.0. ~ Disease.type, data = s_merged)
TukeyHSD(aov(LacCer.d18.1.16.0. ~ Disease.type, data = s_merged))

  
  
# B. TARGETED serum ----

## 1. targeted tryptophan ----
getSheetNames('V2.0_SerumTryptophan.xlsm')
s_tryp= read_excel('V2.0_SerumTryptophan.xlsm', sheet = 'Inception cohort')

# data exploration 
s_tryp = colClean(s_tryp)
colnames(s_tryp)
typeof(s_tryp$Tryptophan)

s_tryp = s_tryp %>% 
  mutate(Disease.type = str_replace_all(Disease.type, 'healthy control', 'Healthy control')) %>%  
  mutate(Disease.type = str_replace_all(Disease.type, 'disease control', 'Disease control')) %>% 
  mutate(Disease.type = as.factor(Disease.type))


# tryptophan 
tryp = s_tryp %>% 
  mutate(Tryptophan = as.numeric(Tryptophan)) %>% 
  select(Tryptophan, Disease.type) %>% 
  kruskal.test(Tryptophan ~ Disease.type, data = .)
summary(tryp)

df = data.frame()
colnames(df)
copy1 = s_merged %>% 
  select( Disease.type, SM.d16.1.24.0.) %>%  
  mutate(Disease.type = str_replace_all(Disease.type, 'healthy control', 'Healthy control')) %>%  
  mutate(Disease.type = str_replace_all(Disease.type, 'disease control', 'Disease control')) %>% 
  mutate(Disease.type = as.factor(Disease.type)) %>% 
  pivot_wider(names_from = Disease.type, values_from = SM.d16.1.24.0.)
filter(Disease.type == 'UC')




## 2. BA ----
getSheetNames('v2.0serum_targ_BAs.xlsm')
hcuc = read_excel('v2.0serum_targ_BAs.xlsm', sheet = 's_HC_UC', header = TRUE)
hccd = read_excel('v2.0serum_targ_BAs.xlsm', sheet = 's_HC_CD')
dcuc = read_excel('v2.0serum_targ_BAs.xlsm', sheet = 's_DC_UC')

#preprocess
s_BA = colClean(s_BA)
s_BA_org = s_BA

dim(s_BA)
s_BA_z = s_BA[,19:ncol(s_BA)]
s_BA[,19:ncol(s_BA)] = (s_BA_z-rowMeans(s_BA_z))/(rowSds(as.matrix(s_BA_z)))[row(s_BA_z)]

s_BA = s_BA %>% 
  arrange(desc(Disease.type), Sample.ID) %>% 
  select(-Sample.point)

colnames(s_BA)

s_BA = s_BA %>%
  mutate(Diet = case_when( Meat == 1 & Vegetarian ==0 ~ 'Meat',
                           Meat == 0 & Vegetarian ==1 ~ 'Vegetarian',
                           Meat == 0 & Vegetarian ==0 ~ 'Vegan')) %>% 
  select(-Meat) %>% 
  select(-Vegetarian) %>% 
  select(-DOB) %>% 
  mutate(Sex.M.1..or.F.0. = case_when( Sex.M.1..or.F.0. == 1 ~ 'Male',
                                       Sex.M.1..or.F.0. == 0 ~ 'Female'))
write.xlsx(s_BA, 'BA_si_z.xlsx')

# preprocess 2 join wih SCFA and tryptophan 


