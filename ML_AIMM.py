#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct  6 16:50:47 2022

@author: weng
Objective: prediction of ML prediction for AIMM score
"""

#% install packages
pip install missingno
pip install sunbird #feature engineering purpose: encoding categorical vars

#% import the packages
import numpy as np
import pandas as pd
import missingno as msno

#% import data: merged portfolio + aimm + gap + wdi

df = pd.read_csv("Data/master.csv")
df = pd.DataFrame()

df.head(5)
df.shape

#% describe the data (missing value and distribution)-----------------
nomi = df.isna().sum() < df.shape[0]/2 #% clean missing data: drop variables with 50% missing.
nomi.value_counts() #only 458 available

msno.bar(df) #plot the missing bar for viz

df = df.loc[:,nomi] #deleted the features with too much missing data

#& impute the missing data. (multivariate feature imputation)------------
dfn = df.select_dtypes(include='number') 
dfs = df.select_dtypes(include='object') 

co_df_imp = np.hstack((dfs.columns.values,dfn.columns.values))

# impute all numerical data with the multivariate feature imputation
from sklearn.experimental import enable_iterative_imputer
from sklearn.impute import IterativeImputer
from sklearn.model_selection import train_test_split

train,test = train_test_split(dfn,train_size = 0.25)
del test
imp.fit(train)
dfn_imp = np.round(imp.transform(dfn))

# impute categorical data with univariate feature imputation
from sklearn.impute import SimpleImputer

imp = SimpleImputer(strategy="most_frequent")
dfs_imp = imp.fit_transform(dfs)

# update the master data with all imputed results
df_imp = pd.concat([pd.DataFrame(dfs_imp),pd.DataFrame(dfn_imp)],axis = 1)
df_imp.columns = co_df_imp

df_imp.to_csv("Data/master_impute.csv")
df = df_imp.loc[:,~df_imp.columns.str.contains('\\.y$',case=False)] #remove the merge duplications

#% data cleaning, encode categorical variables, deal date variables ------------
df_string_column = df.select_dtypes(include='object').columns.values

from sunbird.categorical_encoding import target_guided_encoding
test_df = df.loc[1:5,['owning_region_code','ex_ante_aimm_score']] #test with limited data
test = target_guided_encoding(test_df, 'owning_region_code','ex_ante_aimm_score')

#% feature selection] -----------------
##select numerical features (mostly WDI) https://scikit-learn.org/stable/modules/feature_selection.html#feature-selection
from sklearn.model_selection import train_test_split

df_X = df.loc[:,~df.columns.str.contains('_potential|_score|_rating|_likelihood', case=False)]
dfn_X = df_X.select_dtypes('number')
dfn_column = dfn_X.columns.values

df_Y = df.loc[:,df.columns.str.contains('_potential|_score|_rating|_likelihood', case=False)]

# Split dataset to select feature and evaluate the classifier 
X = dfn_X.to_numpy()
y = df_Y.loc[:,'ex_ante_aimm_score'].to_numpy()

# Tree-based feature selection ----------
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.feature_selection import SelectFromModel

clf = ExtraTreesClassifier(n_estimators=50)
clf = clf.fit(X, y)
clf.feature_importances_  

model = SelectFromModel(clf, prefit=True)
X_new = model.transform(X)
X_new.shape  #36 features from 436 numeric variables. 

df_X_new = pd.DataFrame(X_new)
X_new_des = df_X_new.describe()

nvar_imptc =pd.DataFrame(np.transpose(np.stack((dfn_column, importance))))
nvar_imptc.columns = ["var","importance"]
nvar_imptc.sort_values(by="importance",ascending=False).head(50)


